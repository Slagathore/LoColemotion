"""Fresh two-start confirmation of every retained constrained-feedback lead.

The candidate set and recipes come from the completed search. The same pair
must pass both starts; per-start winners cannot be combined into a success.
Recovery eligibility remains a separate, unchanged assessment.
"""
import copy
import hashlib
import json
import math
from pathlib import Path

from creature_batch import require
import creature_righting as righting
import creature_trajectory_search as trajectory

ROOT = Path(__file__).resolve().parents[2]
SOURCE = dict(path="sdk/discovery/creature_response_search_native_result_v2.json",
    sha256="1166c3d4f31d62016ef47125c400f4664f9e8feaf50f383ed74e0357ad389765")
DECLARATION = "sdk/discovery/creature_response_confirmation_v1.json"
ROUTE_DECLARATION = "sdk/discovery/creature_response_confirmation_route_v1.json"
POLICY = dict(schema_version="locolemotion_response_confirmation_v1", source=SOURCE,
    selection="all_retained_progress_leads", source_pair_count=13, source_body_count=11,
    seed=1061147, initial_roll_offset_rad=.05, outer_steps=1440,
    route_body_index=14, route_profile_indices=[5, 10], route_outer_steps=2,
    minimum_peak_rotation_gain_degrees=5., require_same_pair_at_both_starts=True,
    fresh_reference_source_indices=[0, 1, 2], recovery_qualified=False,
    controller_adopted=False, training_data_authority=False, release_authority=False)


def enabled(c):
    return "response_confirmation" in c


def document(pin):
    raw = (ROOT / pin["path"]).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == pin["sha256"], "Response confirmation source binding")
    return json.loads(raw)


def source_data():
    result = document(SOURCE)
    pins = [p for p in result["source_pins"] if p["path"] == "sdk/discovery/creature_response_search_v2.json"]
    require(len(pins) == 1, "Response confirmation source declaration")
    original = document(pins[0])
    selected = []
    for body in result["body_coverage"]:
        for lead in body["progress_leads"]:
            bi, pi = lead["body_index"], lead["candidate_index"]
            require(bi == body["body_index"] and lead["body_id"] == original["righting_spec"]["descriptors"][bi]["morphology_id"]
                and lead["candidate_id"] == original["righting_spec"]["profiles"][pi]["id"]
                and pi >= 5 and pi in original["righting_spec"]["profiles_by_body"][bi]
                and lead["joint_limit_violation_steps"] == lead["response_model_withdrawals"] == 0
                and min(lead["peak_gain_against_timed_degrees"], lead["peak_gain_against_reference_degrees"]) >= 5.,
                "Response confirmation retained lead identity or predicate")
            selected.append((bi, pi))
    require(len(selected) == len(set(selected)) == POLICY["source_pair_count"]
        and len({b for b, _ in selected}) == POLICY["source_body_count"], "Response confirmation complete lead population")
    return original, sorted(selected)


def population(*, route=False):
    original, selected = source_data()
    if route:
        route_pairs = [(POLICY["route_body_index"], p) for p in POLICY["route_profile_indices"]]
        require(set(route_pairs) <= set(selected), "Response confirmation route source pairs")
        selected = route_pairs
    bodies = sorted({b for b, _ in selected})
    profiles = sorted({0, 1, 2} | {p for _, p in selected})
    return original, selected, bodies, profiles


def spec(*, route=False):
    original, selected, bodies, profiles = population(route=route)
    source = original["righting_spec"]
    return dict(schema_version=righting.ASSIGNED_SCHEMA,
        descriptors=[copy.deepcopy(source["descriptors"][b]) for b in bodies],
        profiles=[copy.deepcopy(source["profiles"][p]) for p in profiles],
        profiles_by_body=[[profiles.index(p) for p in profiles if p < 3 or (b, p) in selected] for b in bodies],
        conditions=copy.deepcopy(source["conditions"]), starts=[
            dict(id="inverted_positive_roll", roll_rad=math.pi-POLICY["initial_roll_offset_rad"]),
            dict(id="inverted_negative_roll", roll_rad=-math.pi+POLICY["initial_roll_offset_rad"])])


def validate(c):
    original, _ = source_data()
    route = c["mode"] == "route_ghost"
    require(c.get("response_confirmation") == POLICY and c["mode"] in ("route_ghost", "development_discovery")
        and c.get("response_search") == original["response_search"] and c["righting_spec"] == spec(route=route)
        and c["predecessor"] == SOURCE and c["seed"] == POLICY["seed"]
        and c["outer_steps"] == POLICY["route_outer_steps" if route else "outer_steps"]
        and c["trajectory_screen"] == trajectory.POLICY
        and c["trajectory_reference_by_body"] == [2]*len(c["righting_spec"]["descriptors"]),
        "Response confirmation frozen pairs, starts or criteria")


def source_dependencies():
    return [ROOT / p for p in (SOURCE["path"], "sdk/discovery/creature_response_search_v2.json",
        DECLARATION, ROUTE_DECLARATION, "sdk/discovery/creature_response_confirmation.py",
        "sdk/discovery/test_creature_response_confirmation.py")]


def assess(c, screen):
    """Join already verified trajectory observations without choosing new winners."""
    validate(c)
    righting.verify_expansion(c)
    route = c["mode"] == "route_ghost"
    _, selected, bodies, profiles = population(route=route)
    expected = {(m["body_index"], m["condition_index"], m["start_index"], m["candidate_index"]): m
                for m in c["righting_metadata"]}
    expected_groups = {key[:3] for key in expected}
    observations, group_keys = {}, set()
    for group in screen["groups"]:
        group_key = tuple(group[k] for k in ("body_index", "condition_index", "start_index"))
        require(group_key in expected_groups and group_key not in group_keys and group.get("reference_candidate_index") == 2,
            "Response confirmation duplicate group or crossed reference")
        group_keys.add(group_key)
        for row in group["observations"]:
            key = tuple(row[k] for k in ("body_index", "condition_index", "start_index", "candidate_index"))
            require(key[:3] == group_key and key in expected and key not in observations
                and all(row[k] == v for k, v in expected[key].items()), "Response confirmation crossed or duplicate episode")
            require(all(type(row[k]) in (int, float) and math.isfinite(row[k]) for k in
                    ("peak_rotation_degrees", "peak_gain_against_timed_degrees", "peak_gain_against_reference_degrees"))
                and all(type(row[k]) is int and row[k] >= 0 for k in
                    ("joint_limit_violation_steps", "response_model_withdrawals")), "Response confirmation finite observations")
            observations[key] = row
    require(set(observations) == set(expected), "Response confirmation incomplete episode population")
    reports = []
    for source_body, source_profile in selected:
        bi, pi = bodies.index(source_body), profiles.index(source_profile)
        starts = []
        for si in range(2):
            row = observations[(bi, 0, si, pi)]
            failures = []
            if row["joint_limit_violation_steps"]: failures.append("joint_limit_violation")
            if row["response_model_withdrawals"]: failures.append("response_model_withdrawal")
            if row["peak_gain_against_timed_degrees"] < POLICY["minimum_peak_rotation_gain_degrees"]:
                failures.append("insufficient_gain_against_timed")
            if row["peak_gain_against_reference_degrees"] < POLICY["minimum_peak_rotation_gain_degrees"]:
                failures.append("insufficient_gain_against_unchanged")
            starts.append(dict(copy.deepcopy(row), passed=not failures, failure_codes=failures))
        reports.append(dict(source_body_index=source_body, source_candidate_index=source_profile,
            body_index=bi, candidate_index=pi, body_id=starts[0]["body_id"], candidate_id=starts[0]["candidate_id"],
            starts=starts, starts_passed=sum(s["passed"] for s in starts),
            confirmed=not route and all(s["passed"] for s in starts)))
    identities = ("source_body_index", "source_candidate_index", "body_id", "candidate_id")
    return dict(schema_version="locolemotion_response_confirmation_assessment_v1", source=SOURCE,
        full_horizon=not route, world_count=len(expected), pair_count=len(reports), pairs=reports,
        confirmed_pairs=[{k: r[k] for k in identities} for r in reports if r["confirmed"]],
        failed_pair_count=sum(not r["confirmed"] for r in reports),
        bodies_with_confirmed_pair=len({r["source_body_index"] for r in reports if r["confirmed"]}),
        finite_progress_only=True, recovery_qualified=False, controller_adopted=False, trained=False,
        tier2_qualified=False, tier3_benefit_established=False, training_data_authority=False,
        physical_acceptance_authority=False, release_authority=False)


def verify_route(receipt):
    """The short route tests new wiring; existing controls cover controller branches."""
    from creature_response_search import initial_metrics, validate_metrics
    c, audit = receipt["contract"], receipt["audit"]
    validate(c)
    righting.verify_expansion(c)
    require(c["mode"] == "route_ghost" and len(c["cells"]) == 10 and audit["ok"] is True
        and audit["synthetic"] is False and audit["reader_world_build_count"] == 0 and audit["gpu_worlds"] == 10
        and audit["controller_rows_replayed"] == 20 and audit["native_rows_verified"] == 100,
        "Response confirmation route population or full replay")
    rows = []
    for meta, metric in zip(c["righting_metadata"], audit["metrics"], strict=True):
        validate_metrics(c, meta, metric)
        pi = meta["candidate_index"]
        require(metric["response_search_failures"] == 0, "Response confirmation route model withdrawal")
        if pi == 2:
            require(metric["response_search_unchanged"] == 2, "Response confirmation unchanged route missing")
        elif pi > 2:
            require(metric["response_search_constraint_rows"] == 2 and metric["response_search_replans"] >= 1,
                "Response confirmation protected selection route missing")
        rows.append(dict(meta, **{k: metric[k] for k in initial_metrics(c)}))
    # StreamValidator has already compared the first prepared and solver input
    # arrays to each declared roll, then checked continuity throughout replay.
    require(audit["response_confirmation"] == assess(c, audit["trajectory_screen"]),
        "Response confirmation route assessment differs")
    return dict(complete=True, worlds=10, controller_rows=20, native_samples=100, cells=rows,
        declared_initial_states_replayed=True, sparse_pair_mapping_verified=True,
        full_horizon_confirmation=False, recovery_benefit_established=False, physical_acceptance_authority=False)
