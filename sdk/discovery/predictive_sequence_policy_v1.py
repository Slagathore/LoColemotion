"""Receding-horizon sequence selection behind the unchanged public resolver.

The adapter prepares model data before constructing this provider. Runtime
policy logic has no engine branch, XML parsing or direct simulator access.
The configured contact law is not a cross-engine equivalence claim.
"""
import copy
import hashlib
from pathlib import Path
import numpy as np
import hierarchical_force_policy_v8 as nominal
from hierarchical_force_policy_v8 import digest,plain,HANDOFF
from prepared_predictive_model import PreparedSelector,validate_model,canonical_packet
from actuation_recovery_mechanics import require,resolve_correction
from predictive_command_selection_v2 import validate as validate_packet
from predictive_sequence_online_v1 import select,next_plan,validate_plan

PROVIDER="configured_predictive_sequence_v1"
VERSION="canonical_receding_sequence_v1"
CONTEXT="locolemotion_predictive_sequence_context_v1"
MEMORY="locolemotion_predictive_sequence_memory_v1"
CORPUS=dict(schema_version="locolemotion_untrained_predictive_origin_v1",trained=False,training_corpus=None)
SOURCES=("predictive_sequence_policy_v1.py","predictive_sequence_control_v1.py","prepared_predictive_model.py",
    "predictive_numeric_backend.py","predictive_command_selection_v2.py","predictive_sequence_online_v1.py","predictive_sequence_v1.py")
FLAGS=("trained","physical_acceptance_authority","tier2_qualified","tier3_benefit_established","cross_engine_equivalence")


def bindings():
    return {name:hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest() for name in SOURCES}


def make_profile(nominal_profile,prepared_model,kernel_sha256):
    return dict(schema_version="locolemotion_predictive_sequence_profile_v1",source_bindings=bindings(),
        nominal_profile=copy.deepcopy(nominal_profile),prepared_model=copy.deepcopy(prepared_model),
        kernel_sha256=kernel_sha256,handoff_command=HANDOFF,
        model_origin="adapter_prepared_configured_parameters",
        policy_input_scope="canonical_observations_declared_model_and_actual_resolved_history",
        **{k:False for k in FLAGS})


class PredictiveRefusal(ValueError):
    def __init__(self,decision):
        super().__init__("Predictive sequence selection refused")
        self.decision=plain(decision)


class Policy:
    def __init__(self,core,profile,kernel_path):
        p=copy.deepcopy(profile);self.core=core;self.profile=p
        require(set(p)=={"schema_version","source_bindings","nominal_profile","prepared_model","kernel_sha256",
            "handoff_command","model_origin","policy_input_scope",*FLAGS}
            and p["schema_version"]=="locolemotion_predictive_sequence_profile_v1"
            and p["source_bindings"]==bindings() and p["handoff_command"]==HANDOFF
            and p["model_origin"]=="adapter_prepared_configured_parameters"
            and p["policy_input_scope"]=="canonical_observations_declared_model_and_actual_resolved_history"
            and all(p[k] is False for k in FLAGS),"Predictive immutable profile/authority")
        require(type(p["kernel_sha256"]) is str and len(p["kernel_sha256"])==64
            and all(c in "0123456789abcdef" for c in p["kernel_sha256"]),"Predictive kernel digest")
        n=p["nominal_profile"];m=p["prepared_model"];validate_model(m)
        require(n["morphology_spec"]==m["morphology_spec"]
            and n["velocity_gains"]==m["velocity_gains"] and n["force_ranges"]==m["force_ranges"]
            and n["parameters"]["joint_inertia_kg_m2"]==m["joint_inertia_kg_m2"]
            and n["reference_root_height_m"]==m["reference_position_m"][1],"Predictive nominal/model join")
        self.nominal=nominal.Policy(core,n)
        self.selector=PreparedSelector(m,kernel_path,p["kernel_sha256"])
        self.sha=digest(core,p);self.model_id="prepared_predictive_"+self.sha[-24:]
        self.prepared_sha=digest(core,m);self.actuators=self.nominal.actuators

    def memory(self,episode):
        inner=self.nominal.memory(episode)
        opaque=dict(schema_version=MEMORY,episode_id=episode,model_sha256=self.sha,
            last_step=HANDOFF-1,previous_binding=None,nominal_memory=inner,plan=None)
        return dict(schema_version="sporespore_adaptation_provider_memory_v1",provider_id=PROVIDER,
            reset_epoch=0,sequence=0,opaque_state=opaque,opaque_state_sha256=digest(self.core,opaque),weights_mutated=False)

    def bind(self,request,stability,memory,episode):
        value=self.nominal.bind(request,stability,memory["opaque_state"]["nominal_memory"],episode)
        value.update(request_id="predictive_"+episode+"_"+str(value["state"]["semantic_step"]),
            provider_id=PROVIDER,expected_provider_version=VERSION,expected_model_id=self.model_id,
            expected_model_sha256=self.sha,expected_training_corpus_id="untrained_prepared_predictive_reference",
            expected_training_corpus_sha256=digest(self.core,CORPUS),provider_memory=copy.deepcopy(memory))
        context=value["controller_context"]
        host=dict(schema_version=CONTEXT,profile_sha256=self.sha,prepared_model_sha256=self.prepared_sha,
            nominal_context=context["controller_memory"])
        context.update(controller_memory_schema_version=CONTEXT,controller_memory=host,
            controller_memory_sha256=digest(self.core,host))
        return value

    def nominal_request(self,request):
        core=self.core;step=request["state"]["semantic_step"];memory=request["provider_memory"];opaque=memory["opaque_state"]
        require(set(opaque)=={"schema_version","episode_id","model_sha256","last_step","previous_binding","nominal_memory","plan"}
            and opaque["schema_version"]==MEMORY and opaque["model_sha256"]==self.sha
            and request["provider_id"]==memory["provider_id"]==PROVIDER
            and request["expected_provider_version"]==VERSION and request["expected_model_id"]==self.model_id
            and request["expected_model_sha256"]==self.sha
            and request["expected_training_corpus_id"]=="untrained_prepared_predictive_reference"
            and request["expected_training_corpus_sha256"]==digest(core,CORPUS)
            and memory["opaque_state_sha256"]==digest(core,opaque)
            and memory["weights_mutated"] is False and type(memory["reset_epoch"]) is int and memory["reset_epoch"]==0
            and type(step) is int and HANDOFF<=step<1440 and type(memory["sequence"]) is int
            and memory["sequence"]==step-HANDOFF and type(opaque["last_step"]) is int and opaque["last_step"]==step-1
            and request["request_id"]=="predictive_"+opaque["episode_id"]+"_"+str(step),
            "Predictive model/memory/episode/clock")
        entries=request["history"]["ordered_entries"];inner=opaque["nominal_memory"]
        require(len(entries)==1 and entries[0]["semantic_step"]==step-1
            and inner["sequence"]==memory["sequence"],"Predictive actual preceding history")
        expected=None if step==HANDOFF else entries[0]["request_sha256"]
        require(opaque["previous_binding"]==inner["opaque_state"]["previous_binding"]==expected,
            "Predictive nominal memory uses actual public request binding")
        context=request["controller_context"];host=context["controller_memory"]
        require(context["controller_memory_schema_version"]==host["schema_version"]==CONTEXT
            and set(host)=={"schema_version","profile_sha256","prepared_model_sha256","nominal_context"}
            and context["controller_memory_sha256"]==digest(core,host)
            and host["profile_sha256"]==self.sha and host["prepared_model_sha256"]==self.prepared_sha
            and context["engine_specific"] is False and context["physical_acceptance_authority"] is False,
            "Predictive bound canonical model context")
        require(all(request[k] is False for k in ("provider_may_build_worlds","provider_may_modify_physics_state",
            "provider_has_physical_acceptance_authority")),"Predictive forbidden request authority")
        value=copy.deepcopy(request)
        value.update(request_id="force_"+opaque["episode_id"]+"_"+str(step),provider_id=nominal.PROVIDER,
            expected_provider_version=nominal.VERSION,expected_model_id=self.nominal.model_id,
            expected_model_sha256=self.nominal.sha,expected_training_corpus_id="untrained_configured_force_reference",
            expected_training_corpus_sha256=digest(core,nominal.CORPUS),provider_memory=copy.deepcopy(inner))
        value["controller_context"].update(controller_memory_schema_version=nominal.CONTEXT,
            controller_memory=copy.deepcopy(host["nominal_context"]),controller_memory_sha256=digest(core,host["nominal_context"]))
        return value

    def respond(self,request):
        core=self.core;internal=self.nominal_request(request);step=request["state"]["semantic_step"]
        decision=dict(step=step,profile_sha256=self.sha,prepared_model_sha256=self.prepared_sha,
            request_sha256=digest(core,request),nominal_prediction_applies_to_transfer=False,
            actual_applied_history_required=True,physical_acceptance_authority=False)
        if request["deterministic_baseline"]["safe_no_actuation"]:
            raise PredictiveRefusal(dict(decision,stage="safe_no_actuation",nominal=None,selection=None))
        try:seed_response,seed=self.nominal.respond(internal)
        except nominal.HierarchyRefusal as exc:
            raise PredictiveRefusal(dict(decision,stage="nominal_refusal",nominal=exc.decision,selection=None)) from exc
        baseline=request["deterministic_baseline"]["ordered_commands"];limits=request["safety_envelope"]["ordered_actuator_limits"]
        require(seed_response["status"]=="applied" and [r["actuator_id"] for r in seed_response["ordered_corrections"]]==self.actuators,
            "Predictive ordered nominal correction")
        commands=dict(baseline=[r["combined_canonical_target_velocity_rad_s"] for r in baseline],
            speeds=[r["maximum_target_speed_rad_s"] for r in baseline],
            previous_correction=[r["previous_applied_correction_rad_s"] for r in limits],
            nominal_correction=[r["canonical_velocity_delta_rad_s"] for r in seed_response["ordered_corrections"]],
            target_com=seed["target_com"],reference_joints=seed["support_reference"]["reference_joint_positions_rad"],command=step)
        starting=canonical_packet(request["state"],commands,self.selector.model.tree.joint_ids)
        envelope,proposal=validate_packet(starting)
        require(np.array_equal(resolve_correction(envelope,proposal)[1],seed["projection"]["target"]),
            "Predictive nominal command identity without an applied-history event")
        decision.update(stage="selection",nominal=seed,nominal_request_sha256=digest(core,internal),
            starting_packet=starting,selection=None)
        prior=request["provider_memory"]["opaque_state"]["plan"]
        validate_plan(prior,starting)
        require(prior is None or prior["request_sha256"]==request["provider_memory"]["opaque_state"]["previous_binding"],
            "Sequence plan actual public binding")
        try:selection=select(self.selector,starting,prior)
        except ValueError as exc:
            raise PredictiveRefusal(dict(decision,stage="selection_error",
                selection_error=dict(type=type(exc).__name__,message=str(exc)))) from exc
        decision["selection"]=selection
        if not selection["accepted"]:raise PredictiveRefusal(decision)
        memory=copy.deepcopy(request["provider_memory"]);opaque=memory["opaque_state"]
        inner=copy.deepcopy(seed_response["next_memory"])
        # The nominal solver's internal request was never applied. Both memory
        # layers bind the actual external request that the core will resolve.
        inner["opaque_state"]["previous_binding"]=decision["request_sha256"]
        inner["opaque_state_sha256"]=digest(core,inner["opaque_state"])
        opaque.update(last_step=step,previous_binding=decision["request_sha256"],nominal_memory=inner,
            plan=next_plan(starting,selection,decision["request_sha256"]))
        memory.update(sequence=step-HANDOFF+1,opaque_state_sha256=digest(core,opaque))
        provenance=dict(provider_id=PROVIDER,provider_version=VERSION,model_id=self.model_id,model_sha256=self.sha,
            training_corpus_id=request["expected_training_corpus_id"],training_corpus_sha256=request["expected_training_corpus_sha256"],
            seed=request["seed"],engine_specific_logic_used=False,direct_world_access_used=False,weights_mutated=False,
            physical_acceptance_authority=False)
        response=dict(schema_version="sporespore_adaptation_provider_response_v1",request_id=request["request_id"],
            request_sha256=decision["request_sha256"],status="applied",confidence=1.,support_distance=0.,
            ordered_corrections=[dict(actuator_id=a,canonical_velocity_delta_rad_s=float(v))
                for a,v in zip(self.actuators,selection["selected_correction"],strict=True)],
            next_memory=memory,provenance=provenance,candidate_experience=None,physical_acceptance_authority=False,
            diagnostics=["untrained configured canonical model; confidence denotes permission, not probability",
                "adapter-prepared model parameters; no cross-engine equivalence or recovery qualification",
                "nominal hierarchy certificate is diagnostic only; selected sequence describes a conditional plan; only the first command is transferred"])
        return response,plain(decision)
