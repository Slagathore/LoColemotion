"""Profile unchanged selection at handoff, a lower speed cap, and refusal."""
import argparse
import cProfile
import json
import pstats
from pathlib import Path
import sys
import predictive_command_selection_v2 as selector
from audit_predictive_command_selection_v2 import ROOT,HERE,GATES,CONTROLS,read,sha,require
from audit_gpu_batch_execution import same_bits
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from gpu_measurement_probe import write_new

CONTRACT=HERE/"predictive_selection_profile_v1.json"
SOURCES=("profile_predictive_selection.py","run_predictive_selection_profile.py")
CLOSURE_RESULT=HERE/"predictive_command_selection_result_v2.json"
RESULT_SHA="bc51a21605f5bd5dc2a39819b8f3cf2c2619b9044b3d197bc7a6f5e5847ccd0d"
PARENT="sdk2-predictive-command-selection-v2-aaa56952527c4d6f878584c13d221225"
PARENT_SHA="236684d90c2a8079ae6efe572748e8d868101e5e77ee11851e923e7831e5962e"
COMMANDS=(60,92,118)


def expected_contract():
    return dict(schema_version="locolemotion_predictive_selection_profile_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_execution_profile",question_class="development"),
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        commands=list(COMMANDS),candidate_evaluations=102,maximum_predicted_steps=510,
        controls_required=69,method="cProfile around selector.select only; full result compared bitwise to retained parent",
        profiling_is_not_a_benchmark=True,worlds_opened=0,native_physics_steps=0,
        source_bindings={name:sha(HERE/name) for name in SOURCES},
        research_sources=["https://docs.python.org/3.11/library/profile.html"])


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Profiler exact declaration");return c


def profile(output):
    contract=declaration();folder=ROOT.parent/"SporeSpore_Evidence"/PARENT
    require(sha(folder/"receipt.json")==PARENT_SHA and sha(CLOSURE_RESULT)==RESULT_SHA,"Profiler parent identity")
    receipt=read(folder/"receipt.json");verify_population(receipt["artifacts"],inventory(folder))
    require(receipt["ok"] and receipt["controls_passed"]==69
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")==receipt["audit_sha256"],
        "Profiler complete parent selection")
    retained=read(folder/"audit.json");parent_result=read(CLOSURE_RESULT)
    native=ROOT.parent/"SporeSpore_Evidence"/parent_result["original_attempt"]/"physical/hierarchy_hold_left_075_train_001"
    model=selector.PredictiveSelector(read(native/"force-profile.json"),(native/"model.xml").read_text(encoding="utf-8"))
    measured=[];matches=[]
    for command in COMMANDS:
        original=retained["results"][command-60];value=original["starting_packet"]
        pr=cProfile.Profile();result=pr.runcall(model.select,value)
        require(same_bits(result,{k:v for k,v in original.items() if k!="starting_packet"}),
            "Profiling changed complete selection output")
        stats=pstats.Stats(pr);rows=[]
        for (filename,line,name),(primitive,total,self_s,cumulative_s,callers) in stats.stats.items():
            rows.append(dict(file=Path(filename).name,line=line,function=name,primitive_calls=primitive,
                total_calls=total,self_s=self_s,cumulative_s=cumulative_s))
        rows.sort(key=lambda r:(-r["self_s"],r["file"],r["line"],r["function"]))
        raw=output.with_name(output.stem+"-command-"+str(command)+".pstats")
        require(not raw.exists(),"Profiler fresh raw artifact");pr.dump_stats(str(raw))
        measured.append(dict(command=command,total_calls=stats.total_calls,total_self_s=stats.total_tt,
            raw_path=raw.name,raw_sha256=sha(raw),functions=rows))
        matches.append(dict(command=command,candidates=len(result["candidates"]),
            selected_index=result["selected_index"],accepted=result["accepted"],complete_result_bitwise_equal=True))
    write_new(output.with_name(output.stem+"-profile.json"),dict(
        schema_version="locolemotion_predictive_selection_profile_measurement_v1",
        ledger_scope=contract["ledger_scope"],profiling_is_not_a_benchmark=True,measurements=measured))
    return dict(schema_version="locolemotion_predictive_selection_profile_audit_v1",ok=True,
        ledger_scope=contract["ledger_scope"],contract_sha256=sha(CONTRACT),parent_receipt_sha256=PARENT_SHA,
        matches=matches,candidate_evaluations=102,worlds_opened=0,native_physics_steps=0,
        controller_changed=False,trained=False,real_time_qualified=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();result=profile(args.output);write_new(args.output,result)
    print(json.dumps(dict(ok=True,commands=list(COMMANDS),output=str(args.output))))
