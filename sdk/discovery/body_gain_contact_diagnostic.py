"""Post-hoc common-prefix contact description; never a selection or causal test."""
from pathlib import Path
from audit_gpu_batch_execution import read_jsonl
from audit_gpu_portable_search import require
from cpu_body_gain_task import sha

SITES = ["front_left_foot","front_right_foot","rear_left_foot","rear_right_foot"]
PREFIX = 180


def support_history(rows, site):
    require(bool(rows) and [r["outer_step"] for r in rows] == list(range(len(rows))), "Contact diagnostic row order")
    flags = []
    for row in rows:
        contacts = row["request"]["state"]["ordered_contact_observations"]
        require([c["contact_site_id"] for c in contacts] == SITES
            and all(type(c["presence"]) is bool and type(c["bears_support"]) is bool
                and (not c["bears_support"] or c["presence"]) for c in contacts), "Contact diagnostic observations")
        c = contacts[SITES.index(site)]; flags.append(c["presence"] and c["bears_support"])
    runs=[];start=None
    for i,value in enumerate(flags+[False]):
        if value and start is None:start=i
        if not value and start is not None:runs.append(dict(first_outer_step=start,last_outer_step=i-1));start=None
    first=next((i for i,v in enumerate(flags) if v),None)
    loss=next((i for i in range(first+1,len(flags)) if not flags[i]),None) if first is not None else None
    recontact=next((i for i in range(loss+1,len(flags)) if flags[i]),None) if loss is not None else None
    return dict(supported_observations=sum(flags),support_runs=runs,first_support_step=first,
        first_loss_after_support_step=loss,first_recontact_after_loss_step=recontact)


def summarize(physical, observed):
    require(len(observed["trials"]) == 10, "Contact diagnostic source population")
    trials=[]
    for trial in observed["trials"]:
        if trial["candidate_indices"] == [0]:continue
        first=trial["metrics"][0]["first_physical_violation"]
        require(first is None or first["internal_step"] > PREFIX*5, "Common prefix crosses first violation")
        path=physical/trial["trial_id"]/"controller.jsonl"
        rows=list(read_jsonl(path))
        require(len(rows) == 480, "Contact diagnostic full controller denominator")
        prefix=rows[:PREFIX]
        trials.append(dict(trial_id=trial["trial_id"],start_id=trial["start_id"],candidate_index=trial["candidate_indices"][0],
            raw_controller_sha256=sha(path),prefix_controller_rows=PREFIX,
            contacts={site:support_history(prefix,site) for site in SITES}))
    require(len(trials) == 8, "Contact diagnostic feedback population")
    return dict(post_hoc=True,prefix_chosen_after_outcome=True,source_trial_count=10,feedback_trial_count=8,
        common_prefix_outer_rows=PREFIX,common_prefix_duration_s=1.5,all_sampled_before_first_physical_violation=True,
        baseline_excluded_from_prefix=True,trials=trials,selection_authority=False,causal_authority=False,
        population_inference=False,qualification_or_release_authority=False)
