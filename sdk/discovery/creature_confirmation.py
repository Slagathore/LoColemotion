"""Frozen sparse confirmation sets and paired finite condition-choice assessment.

The choice is taken from the earlier discovery result, never selected using the
confirmation outcomes. Every source body and condition keeps both comparators.
"""
import copy
import json
import math

from creature_batch import identifier, require
from gpu_quadruped_model import ROOT, sha
import creature_population as population

EXPANDED = ("cells", "initial_lateral_velocities_m_s", "confirmation_metadata",
            "confirmation_plan", "confirmation_profiles", "selection")


def source_records(spec):
    require(type(spec) is dict and set(spec) == {"schema_version", "discovery_contract", "discovery_result",
            "starts", "fixed_candidate_id", "choice_rule"}
            and spec["schema_version"] == "locolemotion_creature_confirmation_v1"
            and spec["choice_rule"] == "first_discovery_shortlist_else_baseline", "Creature confirmation fields")
    records = []
    for key in ("discovery_contract", "discovery_result"):
        binding = spec[key]
        require(type(binding) is dict and set(binding) == {"path", "sha256"}, "Creature confirmation source binding")
        path = (ROOT / binding["path"]).resolve(strict=True)
        require(path.is_relative_to(ROOT) and sha(path) == binding["sha256"], "Creature confirmation source changed")
        records.append(json.loads(path.read_text(encoding="utf-8")))
    contract, result = records
    require(result["schema_version"] == "locolemotion_creature_breadth_native_result_v1"
            and result["status"] == "complete_native_development_discovery"
            and result["contract_path"] == spec["discovery_contract"]["path"]
            and result["contract_sha256"] == spec["discovery_contract"]["sha256"]
            and contract["capture_mode"] == result["capture_mode"] == "full"
            and result["independent_scalar_replay_passed"] is True and result["invalid_worlds"] == 0
            and all(result[k] is False for k in ("trained", "training_data_authority", "physical_acceptance_authority", "release_authority")),
            "Creature confirmation requires valid finite discovery")
    return contract, result


def expand(spec):
    contract, result = source_records(spec)
    source = contract["population_spec"]
    original = population.expand(source)
    require(result["constructed_gpu_worlds"] == len(original["cells"])
            == result["eligible_worlds"] + result["performance_failed_worlds"], "Creature confirmation source denominator")
    population.validate_selection(contract["selection"])
    profiles = source["profiles"]
    ids = [p["id"] for p in profiles]
    require(spec["fixed_candidate_id"] in ids[1:], "Creature fixed comparator")
    fixed = ids.index(spec["fixed_candidate_id"])
    starts = spec["starts"]
    require(type(starts) is list and len(starts) == 2 and all(type(s) is dict
            and set(s) == {"id", "lateral_velocity_m_s"} and identifier(s["id"])
            and type(s["lateral_velocity_m_s"]) in (int, float) and math.isfinite(s["lateral_velocity_m_s"])
            and abs(s["lateral_velocity_m_s"]) <= .005 for s in starts), "Creature confirmation starts")
    require(len({s["id"] for s in starts}) == len({s["lateral_velocity_m_s"] for s in starts}) == 2
            and not ({s["lateral_velocity_m_s"] for s in starts}
                     & {s["lateral_velocity_m_s"] for s in source["starts"]}), "Creature confirmation repeated start")
    groups = result["body_condition_outcomes"]
    expected = [(bi, body["morphology_id"], condition["id"])
                for bi, body in enumerate(source["descriptors"]) for condition in source["conditions"]]
    require([(g["body_index"], g["body_id"], g["condition_id"]) for g in groups] == expected,
            "Creature confirmation omitted or crossed body/condition")
    cells, velocities, metadata, plans = [], [], [], []
    for g in groups:
        bi = g["body_index"]
        ci = next(i for i, condition in enumerate(source["conditions"]) if condition["id"] == g["condition_id"])
        require(sorted(g["eligible_profiles"] + g["failed_profiles"]) == sorted(ids), "Creature confirmation source profile denominator")
        shortlist = [ids.index(p["candidate_id"]) for p in g["shortlist"]]
        require(len(set(shortlist)) == len(shortlist) <= contract["selection"]["shortlist_per_body_condition"]
                and all(i != 0 and ids[i] in g["eligible_profiles"] for i in shortlist), "Creature confirmation source shortlist")
        chosen = shortlist[0] if shortlist else 0
        candidates = sorted({0, fixed, *shortlist})
        plans.append(dict(body_index=bi, body_id=g["body_id"], condition_index=ci, condition_id=g["condition_id"],
            candidate_indices=candidates, shortlist_candidate_indices=shortlist,
            frozen_choice_candidate_index=chosen, fixed_candidate_index=fixed))
        for si, start in enumerate(starts):
            for pi in candidates:
                cell_id = f"body_{bi:03d}_condition_{ci}_start_{si}_candidate_{pi:03d}"
                cells.append(dict(cell_id=cell_id, descriptor=copy.deepcopy(source["descriptors"][bi]),
                    profile=copy.deepcopy(profiles[pi]), motor_effectiveness=copy.deepcopy(source["conditions"][ci]["motor_effectiveness"])))
                velocities.append(start["lateral_velocity_m_s"])
                metadata.append(dict(cell_id=cell_id, body_index=bi, body_id=g["body_id"], condition_index=ci,
                    condition_id=g["condition_id"], start_index=si, start_id=start["id"], candidate_index=pi, candidate_id=ids[pi]))
    require(1 <= len(cells) <= 512, "Creature confirmation world budget")
    return dict(cells=cells, initial_lateral_velocities_m_s=velocities, confirmation_metadata=metadata,
        confirmation_plan=plans, confirmation_profiles=copy.deepcopy(profiles), selection=copy.deepcopy(contract["selection"]))


def verify_expansion(c):
    expected = expand(c["confirmation_spec"])
    require(all(c[key] == value for key, value in expected.items()), "Creature confirmation expansion drift")


def contrast(choice, comparator):
    if choice["eligible"] and comparator["eligible"]:
        outcome = "both_eligible"
    elif choice["eligible"]:
        outcome = "choice_only_eligible"
    elif comparator["eligible"]:
        outcome = "comparator_only_eligible"
    else:
        outcome = "neither_eligible"
    return dict(outcome=outcome, comparator_minus_choice_error_m_s=(
        comparator["mean_velocity_error_m_s"]-choice["mean_velocity_error_m_s"] if outcome == "both_eligible" else None))


def aggregate(groups, comparator):
    rows = [g["comparisons"][comparator] for g in groups]
    counts = {name: sum(r["outcome"] == name for r in rows) for name in
              ("both_eligible", "choice_only_eligible", "comparator_only_eligible", "neither_eligible")}
    gains = [r["comparator_minus_choice_error_m_s"] for r in rows if r["outcome"] == "both_eligible"]
    mean_gain = sum(gains)/len(gains) if gains else None
    # A prospective finite signal, with separate survival and paired-quality facts.
    signal = counts["comparator_only_eligible"] == 0 and (counts["choice_only_eligible"] > 0
        or (mean_gain is not None and mean_gain > 0))
    return dict(body_condition_count=len(rows), counts=counts, paired_eligible_quality_groups=len(gains),
        mean_paired_comparator_minus_choice_error_m_s=mean_gain,
        paired_quality_wins=sum(v > 0 for v in gains), paired_quality_ties=sum(v == 0 for v in gains),
        paired_quality_losses=sum(v < 0 for v in gains), finite_choice_signal=signal)


def assess(c, metrics, bindings):
    verify_expansion(c)
    episodes = population.episode_results(c, metrics, bindings, c["confirmation_metadata"], c["selection"])
    groups = []
    for plan in c["confirmation_plan"]:
        subset = [e for e in episodes if (e["body_index"], e["condition_index"]) == (plan["body_index"], plan["condition_index"])]
        candidates = [population.candidate_summary([e for e in subset if e["candidate_index"] == i],
            i, c["confirmation_profiles"][i]["id"], len(c["confirmation_spec"]["starts"])) for i in plan["candidate_indices"]]
        lookup = {r["candidate_index"]: r for r in candidates}
        policies = dict(baseline=lookup[0], fixed=lookup[plan["fixed_candidate_index"]],
                        frozen_choice=lookup[plan["frozen_choice_candidate_index"]])
        groups.append(dict(plan, candidates=candidates, policies=policies,
            comparisons={name:contrast(policies["frozen_choice"], policies[name]) for name in ("baseline", "fixed")}))
    conditions = list(dict.fromkeys(g["condition_id"] for g in groups))
    return dict(scope="finite_exposed_development_confirmation", world_count=len(episodes),
        eligible_worlds=sum(e["eligible"] for e in episodes), performance_failed_worlds=sum(not e["eligible"] for e in episodes),
        episodes=episodes, body_conditions=groups,
        comparisons={name:aggregate(groups, name) for name in ("baseline", "fixed")},
        comparisons_by_condition={condition:{name:aggregate([g for g in groups if g["condition_id"] == condition], name)
            for name in ("baseline", "fixed")} for condition in conditions},
        choice_origin="frozen_discovery_shortlist_with_true_body_and_condition", choice_refit_on_confirmation=False,
        quality_scope="Equal-weight paired body/condition means only where both policies pass every start; failed quality is null.",
        signal_rule="No body/condition eligibility losses and at least one eligibility gain or positive mean paired velocity-error gain. This finite diagnostic is not statistical superiority or learned adaptation.",
        trained=False, tier2_qualified=False, training_data_authority=False, physical_acceptance_authority=False,
        release_authority=False, equivalence_authority=False)
