"""Configured stance-clearance priority within unchanged predictive guards."""
import copy
import math
import numpy as np
from actuation_recovery_mechanics import array,require
from floating_base_dynamics_inputs import C
from prepared_predictive_model import validate_model
from predictive_command_selection_v2 import validate
from predictive_sequence_v1 import evaluate,parameters
from predictive_sequence_constraint_repair_v1 import rank as feasibility_rank
from predictive_sequence_online_v2 import HORIZON
from sequence_authority_diagnostic_v1 import contact_loads

STRATEGY="stance_clearance_priority_with_unchanged_guard_feasibility"
FOOT_NAMES=tuple(x+"_distal" for x in ("front_left","front_right","rear_left","rear_right"))
ROUNDS=3
CANDIDATES=34


class ClearanceMetric:
    def __init__(self,prepared):
        self.prepared=copy.deepcopy(prepared);self.tree=validate_model(self.prepared).tree
        self.feet=[]
        for i,g in enumerate(self.prepared["ordered_geometry"]):
            if g["body_id"] in FOOT_NAMES:
                require(g["kind"]=="capsule","Contact metric distal capsules")
                self.feet.append((i,g["body_id"],np.array(g["endpoints_local_m"]),g["radius_m"]))
        require(tuple(x[1] for x in self.feet)==FOOT_NAMES,"Contact metric complete distal population")

    def frame(self,qpos):
        q=array(qpos,(15,),"Contact metric position")
        require(abs(float(q[3:7] @ q[3:7])-1.)<=1e-10,"Contact metric unit quaternion")
        return self.tree.kinematics(C @ q[:3],np.r_[C @ q[4:7],q[3]],q[7:])

    def clearance(self,qpos):
        frame=self.frame(qpos)
        return [float(np.min((ends @ frame["rotations"][i].T+frame["positions"][i])[:,1])-radius)
            for i,_,ends,radius in self.feet]

    def score(self,result):
        rows=[]
        for interval in result["rows"]:
            for row in interval["forecast"]["rows"]:
                if "qpos" in row:rows.append(self.clearance(row["qpos"]))
        count=len(rows)
        require(count==result["completed_predicted_steps"],"Contact metric complete predicted states")
        positive=np.maximum(np.array(rows).reshape(count,4),0.)
        return dict(completed_states=count,
            mean_squared_clearance_m2=float(np.mean(positive**2)) if count else None,
            mean_positive_clearance_m=np.mean(positive,axis=0).tolist() if count else None,
            maximum_positive_clearance_m=np.max(positive,axis=0).tolist() if count else None,
            nonpositive_clearance_states=np.sum(np.array(rows)<=0.,axis=0).tolist() if count else [0]*4,
            ordered_distal_bodies=list(FOOT_NAMES),clearance_m=rows,
            geometry_is_loaded_contact=False,training_data_authority=False)


def contact_counts(result,metric):
    """Count retained pre-step contact geometry and positive predicted normals."""
    p=metric.prepared
    spec=dict(joint_ids=metric.tree.joint_ids,
        limits=[[j["lower_limit_rad"],j["upper_limit_rad"]] for j in metric.tree.joints],
        gains=p["velocity_gains"],ranges=p["force_ranges"],
        geom_bodies=["world"]+[g["body_id"] for g in p["ordered_geometry"]])
    geometric=[0]*4;positive=[0]*4;count=0
    for interval in result["rows"]:
        for row in interval["forecast"]["rows"]:
            if "qpos" not in row:continue
            require(row["prediction"]["accepted"] is True,"Contact count finite predicted step")
            loads=contact_loads(row,spec);count+=1
            for j,name in enumerate(FOOT_NAMES):
                geometric[j]+=int(name in loads);positive[j]+=int(loads.get(name,0.)>0.)
    require(count==result["completed_predicted_steps"],"Contact count complete denominator")
    return dict(completed_states=count,ordered_distal_bodies=list(FOOT_NAMES),
        geometric_contact_states=geometric,positive_normal_force_states=positive,
        predicted_pre_step_contacts=True,actual_native_observations=False,dynamic_feasibility_established=False)


def rank(result,score,limits):
    base=feasibility_rank(result,limits);cost=score["mean_squared_clearance_m2"]
    require(cost is None or (type(cost) is float and math.isfinite(cost) and cost>=0.),
        "Contact metric finite squared clearance")
    require(cost is not None or not result["eligible"],"Contact accepted forecast needs geometry")
    return (*base[:4],1e300 if cost is None else cost,base[4])


def search(selector,metric,value,seed,retain):
    validate(value);center=array(seed,(4,8),"Contact initial points").tolist()
    require(np.all(np.abs(center)<=3.5),"Contact initial knot bounds")
    before=copy.deepcopy((value,seed));rounds=[];winner=None;prior=None;initial=None
    for iteration in range(ROUNDS):
        best=None;eligible=0
        for option in parameters(value,center,iteration):
            result=evaluate(selector,value,option["knots"],HORIZON);score=metric.score(result)
            record=dict(iteration=iteration,option=option,result=result,contact_metric=score)
            retain(record);eligible+=int(result["eligible"])
            if initial is None:initial=record
            if best is None or rank(result,score,selector.limits)<rank(best["result"],best["contact_metric"],selector.limits):
                best=record
        current=rank(best["result"],best["contact_metric"],selector.limits)
        require(prior is None or current<=prior,"Contact incumbent preservation")
        winner=best;center=copy.deepcopy(best["option"]["knots"]);prior=current
        rounds.append(dict(iteration=iteration,evaluated=CANDIDATES,eligible_candidates=eligible,
            winner_index=best["option"]["index"],rank=list(current)))
    require((value,seed)==before,"Contact immutable causal inputs")
    require(not initial["result"]["eligible"] or winner["result"]["eligible"],"Contact preserve admitted incumbent")
    return dict(strategy=STRATEGY,rounds=rounds,best=winner,evaluated_candidates=102,horizon=HORIZON,
        accepted=winner["result"]["eligible"],initial_metric=initial["contact_metric"],
        initial_eligible=initial["result"]["eligible"],finite_search_only=True,
        original_decision_ordering_preserved=False,guard_predicates_changed=False,actuator_caps_changed=False,
        trained=False,actual_native_transfer_verified=False,recovery_benefit_established=False,
        tier2_qualified=False,tier3_benefit_established=False,training_data_authority=False,
        physical_acceptance_authority=False,release_authority=False,global_infeasibility_established=False)
