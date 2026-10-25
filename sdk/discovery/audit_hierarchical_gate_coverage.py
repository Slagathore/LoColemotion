"""Close the retired-backend gate failure and prove active assertion coverage."""
import argparse
import ast
import copy
import json
import re
from pathlib import Path
import hierarchical_native_task_v5 as task
from hierarchical_native_task_v5 import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v5 import inventory
from run_residual_native import verify_tests
from run_gpu_measurement_probe import source_identity
from gpu_measurement_probe import write_new

CONTRACT=HERE/"hierarchical_gate_coverage_v1.json"
PARENT_RESULT=HERE/"proximal_repeatability_result_v1.json"
SOURCES=("audit_hierarchical_gate_coverage.py","test_hierarchical_gate_coverage.py",
    "run_hierarchical_gate_coverage.py")
ATTEMPT="sdk2-hierarchical-native-v5-f1388d93796b4828b60c558ffba9b89f"
SOURCE="01785eca265d3348c1559e9616d93abb0e78c762"
RECEIPT_SHA="13befccead87b043b36dc8a8679f3cbbf838638db6b1ebf6298d5a77354c89a7"
DECLARATION_SHA="832f2c25d6acb8e2143196e814b5051854a6f48951b3f6c02f283bf64e980768"
FAILED_GATE="hierarchy-hierarchical-policy-v4"
FAILED_TEST="test_05_current_measured_load_is_unused"
PAIRS=(
    ("hierarchy-proximal-qp","test_proximal_qp_solver","hierarchy-generic-qp","test_generic_proximal_qp_solver",14,16,
     {"proximal_qp_solver":"generic_proximal_qp_solver"},
     ("test_15_conflicting_backend_refuses_before_loading","test_16_generic_backend_identity_and_repeat_import")),
    ("hierarchy-proximal-hierarchy","test_proximal_contact_component","hierarchy-generic-hierarchy","test_generic_proximal_contact_component",20,20,
     {"proximal_contact_component":"generic_proximal_contact_component"},()),
    ("hierarchy-hierarchical-policy-v4","test_hierarchical_force_policy_v4","refinement-public-policy-v8","test_hierarchical_force_policy_v8",17,17,
     {"hierarchical_force_policy_v4":"hierarchical_force_policy_v8","hierarchical_hold_control_v4":"hierarchical_hold_control_v8"},()),
)
COVERAGE_CONTROLS=8
GATES=(("coverage","test_hierarchical_gate_coverage",COVERAGE_CONTROLS),
    *((n,m,c) for _,_,n,m,_,c,_,_ in PAIRS))
CONTROLS=sum(c for _,_,c in GATES)
DENIALS=(*task.FLAGS,"tier2_qualified","tier3_benefit_established","recovery_benefit_established",
    "dynamic_feasibility_established","automatic_backend_failure_cause_proved","universal_repeatability_established")

def coverage_pair(old_text,new_text,pair):
    """Compare the entire module AST; only named imports/providers may change."""
    _,old,_,new,old_count,new_count,substitutions,extras=pair
    a=ast.parse(old_text);b=ast.parse(new_text)
    # Replacements are exact module identifiers, never assertion/tolerance edits.
    class Substitute(ast.NodeTransformer):
        def visit_Import(self,node):
            for alias in node.names:alias.name=substitutions.get(alias.name,alias.name)
            return node
        def visit_ImportFrom(self,node):
            node.module=substitutions.get(node.module,node.module);return node
        def visit_Constant(self,node):
            if isinstance(node.value,str):
                for old,new in substitutions.items():
                    if node.value==old+".py" or node.value.startswith(old+"."):
                        node.value=new+node.value[len(old):]
                        break
            return node
    a=Substitute().visit(a)
    def tests(tree):
        return [n.name for c in tree.body if isinstance(c,ast.ClassDef)
            for n in c.body if isinstance(n,ast.FunctionDef) and n.name.startswith("test_")]
    before=tests(a);after=tests(b)
    require(len(before)==len(set(before))==old_count and len(after)==len(set(after))==new_count
        and set(after)-set(before)==set(extras) and set(before)<=set(after),"Coverage exact test population")
    for cls in b.body:
        if isinstance(cls,ast.ClassDef):
            cls.body=[n for n in cls.body if not isinstance(n,ast.FunctionDef) or n.name not in extras]
    require(ast.dump(a,include_attributes=False)==ast.dump(b,include_attributes=False),
        "Coverage full module assertions fixtures and helpers differ")
    return dict(legacy_module=old,active_module=new,legacy_controls=old_count,active_controls=new_count,
        module_substitutions=substitutions,extra_controls=list(extras),preserved_controls=before,
        full_normalized_module_ast_equal=True)

def coverage():
    result=[]
    for pair in PAIRS:
        old=HERE/(pair[1]+".py");new=HERE/(pair[3]+".py")
        result.append(dict(coverage_pair(old.read_text(encoding="utf-8"),new.read_text(encoding="utf-8"),pair),
            legacy_sha256=sha(old),active_sha256=sha(new)))
    return result

def completed_gates():
    names=[n for n,_,_ in task.GATES];index=names.index(FAILED_GATE)
    result=task.GATES[:index]
    require(sum(c for _,_,c in result)==700,"Coverage original completed gate denominator")
    return result

def expected_contract():
    return dict(schema_version="locolemotion_hierarchical_gate_coverage_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="retained_gate_failure_and_active_coverage",question_class="development"),
        original_attempt=ATTEMPT,original_source_commit=SOURCE,original_receipt_sha256=RECEIPT_SHA,
        original_declaration_sha256=DECLARATION_SHA,original_contract_sha256=sha(task.CONTRACT),
        original_completed_controls=700,failed_module_controls=17,failed_assertions=1,
        original_artifacts_including_receipt=2637,original_source_binding_count=1008,
        original_runtime_binding_count=3582,failed_gate=FAILED_GATE,failed_test=FAILED_TEST,
        historical_repeatability_result_sha256=sha(PARENT_RESULT),
        public_result_sha256=sha(task.COMPONENT_RESULT),
        active_coverage=coverage(),closure_controls_required=CONTROLS,
        legacy_controls_represented=51,active_controls=53,coverage_controls=COVERAGE_CONTROLS,
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        worlds_opened=0,solver_steps=0,legacy_assertions_changed=False,
        production_controller_changed=False,numerical_guards_changed=False,
        **{k:False for k in DENIALS})

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Coverage exact declaration");return c

def validate_owner(r,d,c):
    require(r["schema_version"]=="locolemotion_hierarchical_native_owner_v5"
        and r["ok"] is False and r["synthetic"] is False and r["source_commit"]==SOURCE
        and r["contract"]==d["contract"]==c and r["binding"]==d["binding"]
        and r["source_status"]==d["source_status"]==[]
        and len(r["binding"]["source"])==1008 and len(r["binding"]["runtime"])==3582
        and r["safety_controls"]=={n:k for n,_,k in completed_gates()}
        and r["planned_trials"]==d["planned_trials"]==task.plans(c)
        and r["planned_worlds"]==dict(cpu=4,gpu=0)
        and all(r[k] is False for k in (*task.FLAGS,"physical_started","component_only","physical_launch_requested"))
        and r["constructed_cpu_worlds"]==r["constructed_gpu_worlds"]==0
        and "zero_world_gate_passed" not in r and "component_controls_passed" not in r
        and r["error"]=="RuntimeError: Contained stage failed (1): "+str(ROOT.parent/"SporeSpore_Evidence"/ATTEMPT/(FAILED_GATE+"-gate")),
        "Coverage exact failed owner and zero-world boundary")

def validate_failure_log(log):
    rows=re.findall(r"^(test_\w+) \([^\n]+\) \.\.\. (ok|FAIL|ERROR|skipped.*?)$",log,re.M)
    require(len(rows)==17 and len({n for n,_ in rows})==17
        and [(n,s) for n,s in rows if s!="ok"]==[(FAILED_TEST,"FAIL")]
        and re.search(r"^Ran 17 tests in [0-9.]+s$",log,re.M)
        and log.rstrip().endswith("FAILED (failures=1)")
        and "self.assertEqual(d,changed)" in log and "AssertionError:" in log
        and "Diff is 528173 characters long." in log,
        "Coverage exact observed equality failure; complete differing values unavailable")

def audit(evidence,core_path,baseline_path):
    c=declaration();current=source_identity(False);folder=evidence/ATTEMPT
    require(folder.resolve().parent==evidence.resolve()
        and sha(folder/"receipt.json")==RECEIPT_SHA and sha(folder/"declaration.json")==DECLARATION_SHA,
        "Coverage original evidence identities")
    r=read(folder/"receipt.json");d=read(folder/"declaration.json")
    validate_owner(r,d,task.declaration());validate_bindings(r["binding"])
    verify_population(r["artifacts"],inventory(folder))
    require(len(r["artifacts"])==2636 and not any((folder/name).exists()
        for name in ("physical","consumed.json","gate-receipt.json","component-receipt.json",
            "audit.json","reconstruction.json")),"Coverage unopened physical and completion records")
    for name,_,count in completed_gates():verify_tests(folder/(name+"-gate"),count)
    stage=folder/(FAILED_GATE+"-gate");validate_failure_log((stage/"stderr.log").read_text(encoding="utf-8"))
    leaf=read(stage/"leaf.json")
    require(leaf["command"][-1]=="test_hierarchical_force_policy_v4"
        and Path(leaf["env"]["QUADRUPED_TEST_CORE"]).resolve()==core_path.resolve()
        and sha(core_path)==task.declaration()["core_sha256"]
        and sha(baseline_path)==task.declaration()["baseline_core_sha256"],"Coverage failed module runtime join")
    # Read historical automatic-backend evidence without loading its backend.
    prior=read(PARENT_RESULT);old=evidence/prior["attempt_id"]
    require(prior["status"]=="complete_retained_repeatability_failure_diagnosis"
        and prior["readers_bitwise_equal"] is False and prior["declared_input_populations_identical"] is True,
        "Coverage historical negative retained")
    for name in ("receipt","declaration","audit","reconstruction"):
        require(sha(old/(name+".json"))==prior[name+"_sha256"],"Coverage historical record identity")
    old_owner=read(old/"receipt.json");old_decl=read(old/"declaration.json")
    require(old_owner["ok"] is True and old_owner["controls_passed"]==36
        and old_owner["worlds_opened"]==old_owner["solver_steps"]==0,"Coverage historical zero-world scope")
    validate_bindings(old_decl["binding"]);verify_population(old_owner["artifacts"],inventory(old))
    task.verify_component(evidence)
    active=coverage()
    require(source_identity(False)==current,"Coverage reader source drift")
    return dict(schema_version="locolemotion_hierarchical_gate_coverage_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],original_attempt=ATTEMPT,original_receipt_sha256=RECEIPT_SHA,
        original_source_commit=SOURCE,original_complete_gate_passed=False,
        original_completed_controls=700,failed_module_controls=17,failed_module_passes=16,failed_assertions=1,
        failed_test=FAILED_TEST,artifact_count_including_receipt=2637,source_binding_count=1008,runtime_binding_count=3582,
        active_coverage=active,legacy_controls_represented=51,active_controls=53,
        historical_repeatability_result_sha256=sha(PARENT_RESULT),public_result_sha256=sha(task.COMPONENT_RESULT),
        complete_original_artifact_population_verified=True,legacy_assertions_changed=False,
        production_controller_changed=False,numerical_guards_changed=False,
        maximum_current_difference=None,current_failure_cause="unresolved; retained exact equality failure",
        reader_world_build_count=0,reader_solver_steps=0,**{k:False for k in DENIALS})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();v=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,v);print(json.dumps(dict(ok=True,legacy_controls=51,active_controls=53,worlds_opened=0)))
if __name__=="__main__":raise SystemExit(main())
