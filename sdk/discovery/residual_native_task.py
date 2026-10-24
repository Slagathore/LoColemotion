"""Prospective CPU route smoke for immutable residuals; no training authority."""
import copy
import hashlib
import json
from pathlib import Path

from adaptation_provider import bounded_residual_ars_v1 as ars
from adaptation_provider import bounded_residual_provider_v1 as provider
from gpu_quadruped_model import ROOT,FLAGS,f32
from portable_search_control import contract as foundation,bridge
from residual_control import expected_provider

HERE=Path(__file__).resolve().parent
CONTRACT=HERE/"residual_native_smoke_v1.json"
require=ars.require
SOURCES=("residual_native_task.py","residual_native.py","audit_residual_native.py",
         "run_residual_native.py","test_residual_native.py")
ROLES=(
    dict(id="absent",mode="absent",model_kind="zero"),
    dict(id="zero",mode="frozen",model_kind="zero"),
    dict(id="probe",mode="frozen",model_kind="probe"))
GATES=(
    ("measurement","test_actuation_measurement",7),
    ("quadruped","test_gpu_quadruped_probe",10),
    ("portable","test_portable_search",11),
    ("motor-task","test_motor_effectiveness_task",7),
    ("cpu-motor","test_cpu_motor_challenge",7),
    ("causal-history","test_history_influence_control",5),
    ("residual-optimizer","test_bounded_residual_ars",10),
    ("residual-provider","test_bounded_residual_provider",12),
    ("residual-native","test_residual_native",13))
EXPECTED_CONTROLS=sum(count for _,_,count in GATES)+3


def sha(path):
    with Path(path).open("rb") as stream:return hashlib.file_digest(stream,"sha256").hexdigest()


def expected_declaration():
    base=foundation()
    return dict(schema_version="locolemotion_residual_native_smoke_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="development_smoke",question_class="development"),
        purpose="Verify the actual residual route constructs, steps, captures, closes and independently replays three fresh native worlds.",
        core_sha256="f88cb47a720802ac95d3f4553bd238f5812a6e9b291b17f5e2717708aa3d5b99",
        baseline_core_sha256="5fafe9a27578e4fbd642d7dd83599ff221853b095ab628e54a9c4f1e09d5f977",
        runtime={k:base["runtime"][k] for k in ("mujoco","numpy")},
        provider_definition=provider.definition(),
        model_xml_sha256=base["model_xml_sha256"],
        condition_model_sha256=dict(nominal="27ba35d5925099e22a757b232808ad3bbaae7fa7b55b912396ece2fd7bb1b6ec"),
        descriptor_sha256=base["descriptor_sha256"],
        conditions=[dict(condition_id="nominal",side="none",effectiveness=1.)],
        policy_id=base["policy_id"],stability_policy_id=base["stability_policy_id"],phase_mode="clocked",
        seed=104240301,outer_steps=120,internal_steps_per_outer=5,
        timestep_s=1/600,controller_dt_s=1/120,horizon_s=1.,warmup_outer_steps=0,
        initial_native_lateral_velocity_m_s=.001,
        initial_values="float32_equalized_inputs_then_native_float64_cpu_dynamics",
        roles=copy.deepcopy(list(ROLES)),planned_cpu_worlds=3,planned_gpu_worlds=0,
        model_kind="immutable_untrained_interface_stimuli",
        probe_weights=dict(height=.06,velocity=-.002,phase_sine=.01,alternating_height_sign=True),
        cpu_warning_count=7,naconmax=256,naconmax_per_world=256,njmax=128,
        selection={k:base["selection"][k] for k in ("minimum_height_m","maximum_tilt_rad","maximum_torso_contact_steps")},
        maximum_trace_bytes_per_trial=128*2**20,maximum_worker_wall_seconds=180,maximum_reader_wall_seconds=180,
        safety_controls=[dict(name=name,module=module,count=count) for name,module,count in GATES],
        provider_controls=2,containment_controls=1,complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={p:sha(HERE/p) for p in SOURCES},
        source_host=dict(path="sdk/discovery/residual_control.py",sha256=sha(HERE/"residual_control.py")),
        coverage=["three fresh native model/data/controller instances at one development start",
            "lossless model artifact load and private sequential provider history",
            "unchanged baseline and exact zero-residual native trajectory",
            "nonzero residual transferred through adapter mapping into held native solver inputs",
            "complete prepared observations, internal states, forces, contacts and timing",
            "independent baseline-core control replay and causal trace joins",
            "failure retention, source freeze, global serialization and process containment"],
        not_covered=["native training or training reward","whole-gait-cycle or full-horizon performance",
            "weakened conditions","calibrated confidence","Tier 3 memory benefit",
            "reserved evaluation","other morphology or engine","equivalence","qualification or release"],
        controller_selection_authority=False,adaptation_benefit_established=False,
        tier3_benefit_established=False,**{k:False for k in FLAGS})


def declaration():
    value=json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value==expected_declaration(),"Residual native declaration/source bindings")
    return value


def model_artifact(kind):
    require(kind in ("zero","probe"),"Residual route model kind")
    names=provider.features.NAMES
    weights=[[0.]*len(names) for _ in range(8)]
    if kind=="probe":
        for i,row in enumerate(weights):
            row[names.index("height_m")]=(-1.)**i*.06
            row[names.index(provider.features.JOINTS[i]+"_velocity_rad_s")]=-.002
            row[names.index(provider.features.LEGS[i//2]+"_phase_sin")]=.01
    policy=ars.Policy(tuple(tuple(r) for r in weights),ars.Moments.empty(len(names)),(3.5,)*8,1e-8)
    return provider.artifact(policy,dict(corpus_id="untrained_native_residual_route_v1",
        kind="untrained_development_probe",source_record_sha256=None,training_data_authority=False))


def trial_plan(c):
    return [dict(trial_id="route_nominal_"+r["id"],group_id="route_nominal_start_001",
        partition="development_smoke",condition_id="nominal",role=r["id"],mode=r["mode"],
        model_kind=r["model_kind"],seed=c["seed"],nworld=1,arm="scalar_direct",
        initial_native_lateral_velocity_m_s=c["initial_native_lateral_velocity_m_s"],
        training_data_authority=False) for r in c["roles"]]


def initial_arrays(spec,plan):
    qpos=list(map(f32,spec["initial_qpos"]));qpos[3:7]=[1.,0.,0.,0.]
    qvel=[0.]*14;qvel[1]=f32(plan["initial_native_lateral_velocity_m_s"])
    return qpos,qvel


def controller_contract(c,model):
    return dict(c,provider=expected_provider(model))
