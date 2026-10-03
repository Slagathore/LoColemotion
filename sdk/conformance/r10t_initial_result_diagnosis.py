"""Post-exposure host-declaration diagnosis; never upgrades the consumed attempt."""
import argparse
import json
from pathlib import Path
from unittest import mock
import development_recovery_smoke as smoke
import development_passive_entry_profile as entry
import r10t_route_integration_component as base

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RUN = EVIDENCE/'development-recovery-smoke-108ce23f94694d61ab90acb1495a4fb0'
KEY = ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v25.json'
DESIGN = ROOT/'sdk/recovery/r10t_post_recovery_settling_design_v1.json'


def run(directory):
    directory = Path(directory).resolve()
    assert directory.parent == EVIDENCE.resolve() and not directory.exists()
    directory.mkdir()
    original = base.read(RUN/'independent_audit.stdout.json')
    supervisor = base.read(RUN/'supervisor_result.json')
    declaration = base.read(RUN/'declaration.json')
    design = base.read(DESIGN)
    declared = design['limits']['per_child_wall_seconds']
    assert original['ok'] is False and original['failure_code'] == 'DEVELOPMENT_PASSIVE_PROFILE_DECLARATION_timeout_seconds_per_child'
    assert supervisor['ok'] is False and supervisor['failure_code'] == 'SMOKE_INDEPENDENT_AUDIT_FAILED'
    assert declared == declaration['timeout_seconds_per_child'] == 1740
    assert entry.CHILD_TIMEOUT_SECONDS == 1500
    assert design['development_coverage']['if_first_not_valid_positive'].startswith('Close the R10T development chain')
    for item in base.read(KEY)['bound_source_files']:
        assert base.bind(ROOT/item['path'])['raw_sha256'] == item['raw_sha256'], item['path']
    before = entry._source_snapshot()
    base.write_new(directory/'source_before.json', before)
    bindings = [base.bind(path) for path in [RUN/'declaration.json', RUN/'supervisor_result.json',
        RUN/'independent_audit.stdout.json', DESIGN, KEY, Path(__file__)]]
    base.write_new(directory/'diagnostic_declaration.json', dict(
        schema_version='sporespore_r10t_host_declaration_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        bindings=bindings, original_validator_host_seconds=1500, frozen_design_host_seconds=1740,
        intervention='In-memory substitution of only the host timeout constant while invoking the original full auditor on original files. No physical execution and no retained input rewrite.',
        original_attempt_reclassified=False, r10t_development_chain_closed=True,
        paired_launch_authorized=False, physical_acceptance_authority=False, release_authority=False))
    result = None
    failure = ''
    try:
        with mock.patch.object(entry, 'CHILD_TIMEOUT_SECONDS', declared):
            result = smoke.audit(RUN)
    except (ValueError, KeyError, TypeError, OSError) as error:
        failure = str(error)
    finally:
        after = entry._source_snapshot()
        base.write_new(directory/'source_after.json', after)
        assert after == before
        for item in bindings: base.verify(item)
    record = dict(schema_version='sporespore_r10t_host_declaration_diagnosis_result_v1',
        ok=not failure and result is not None and result['ok'] is True, failure_code=failure,
        diagnostic_audit=result, source_unchanged=True, world_build_count=0, solver_step_count=0,
        original_attempt_reclassified=False, r10t_development_chain_closed=True,
        paired_launch_authorized=False, physical_acceptance_authority=False, release_authority=False)
    base.write_new(directory/'result.json', record)
    finite = result.get('r10t_finite_development', {}) if result else {}
    return dict(directory=str(directory), ok=record['ok'], failure_code=failure,
        diagnostic_all_tasks_positive=finite.get('all_tasks_positive'),
        diagnostic_branch_coverage_complete=finite.get('branch_coverage_complete'),
        original_attempt_reclassified=False, r10t_development_chain_closed=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('directory'); args = parser.parse_args()
    print(json.dumps(run(args.directory)))
