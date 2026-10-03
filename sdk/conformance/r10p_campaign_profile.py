"""R10P campaign boundary over the unchanged R10O physical candidate protocol.

The generic candidate loader continues to validate the DLL, schedule, controls
and source bindings. This separate layer selects the R10P worker and validates
its campaign publication without changing any historical profile or reader.
"""
import development_passive_entry_profile as entry
import development_recovery_candidate as candidate
import development_step_cost_profile as capture
import qsdk_r10f_l15_collection_retention as packet
import r10p_campaign_authority as authority

WORKER = 'res://sdk/adapters/godot/gdscript/r10p_campaign_worker_v1.gd'
ROUTE = 'r10o_v55_partial_fall_recovery_route_v1'
DLL_SHA = 'sha256:c9303b0e7209f63c8b132a271d1ec32ce69f8768409f22d1f4cee6fcd12a5437'


def require(value, code):
    if not value:
        raise ValueError('R10P_CAMPAIGN_PROFILE_' + code)


def reference():
    return candidate.reference_for_path(candidate.ROOT / authority.CANDIDATE_RESOURCE.removeprefix('res://'))


def selection(bound=None):
    bound = reference() if bound is None else bound
    require(packet.same(bound, reference()), 'CANDIDATE_IDENTITY')
    chosen = candidate.selection(bound)
    require(chosen['diagnostic_schedule']['walking_policy_id'] == ROUTE
            and chosen['candidate']['runtime_sha256'] == DLL_SHA
            and chosen['post_kick_controller_id'] == 'sporespore_exact_s169_prone_to_standing_controller_v20',
            'PHYSICAL_ROUTE')
    chosen['worker_selection'] = dict(chosen['worker_selection'], worker=WORKER)
    return chosen


def validate_declaration(declaration):
    chosen = selection(declaration.get('candidate_profile'))
    candidate.declared_roles(declaration)
    worker, bounds = chosen['worker_selection'], candidate.limits(chosen)
    expected = dict(bounds, schema_version=worker['declaration_schema'],
        diagnostic_schedule_id=worker['schedule'], worker_resource=WORKER,
        passive_entry_runtime=entry.binding(chosen)['runtime'], timeout_seconds_per_child=1500,
        independent_replay_timeout_seconds=900, official_qualification=False,
        physical_acceptance_authority=False, release_authority=False)
    for key, value in expected.items():
        require(packet.same(declaration.get(key), value), 'DECLARATION_' + key)
    require(capture.declared_context_cache(declaration, expected_worker=WORKER), 'CACHE_REQUIRED')
    return dict(bounds)


def validate_campaign_retention(report, declaration, campaign):
    identity = authority.seed_identity(campaign['seed'])
    expected = dict(r10p_campaign=declaration['r10p_campaign'], seed_label=identity['label'],
        seed_sha256=identity['sha256'], held_out=campaign['held_out'],
        held_out_cell_access_count=int(campaign['held_out']))
    for key, value in expected.items():
        require(packet.same(report.get(key), value), 'REPORT_' + key)
    require(not any(key.startswith('r10') and key.endswith(('_campaign', '_development'))
                    and key != 'r10p_campaign' for key in report), 'CROSSED_REPORT_CONTEXT')
