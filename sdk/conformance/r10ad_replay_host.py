"""Declaration-bound host selection for the complete R10AD diagnostic reader."""
import json
from pathlib import Path

import r10ad_development as identity
import r10ad_host_runtime as host
import r10ad_selection as admission


def selected(chosen):
    # A candidate cannot opt in by adding a flag or sharing the native route.
    return chosen.get('candidate_profile', {}).get('resource') == 'res://' + identity.PROFILE.relative_to(identity.ROOT).as_posix()


def deadlines(chosen, declaration):
    identity.require(selected(chosen) and chosen.get('candidate_profile') == identity.reference(), 'REPLAY_PROFILE')
    admission.native_schedule(chosen.get('diagnostic_schedule', {}))
    identity.validate_declaration(declaration)
    host.validate_binding(declaration.get('runtime'))
    design = json.loads(identity.DESIGN.read_text())
    limits = design['limits']
    return (limits['child_wall_time_limit_seconds'], limits['independent_reader_wall_time_limit_seconds'])


def plan(report_path, chosen, report=None):
    report_path = Path(report_path).resolve()
    declaration_path = report_path.parent.parent.parent / 'declaration.json'
    identity.require(report_path.name == 'worker_report.json' and declaration_path.parent.parent == identity.EVIDENCE,
                     'REPLAY_PATH')
    declaration = json.loads(declaration_path.read_text(encoding='utf-8-sig'))
    child_timeout, reader_timeout = deadlines(chosen, declaration)
    expected_path = Path(declaration['children'][0]['evidence_path']) / 'worker_report.json'
    identity.require(report_path == expected_path and declaration_path.parent.name ==
                     'development-recovery-smoke-' + declaration['attempt_id'], 'REPLAY_DECLARED_CHILD_PATH')
    if report is not None:
        identity.validate_report_header(report, declaration)
    return dict(engine_image=host.expected_binding()['images']['godot_engine'], timeout_seconds=reader_timeout,
        declaration_path=str(declaration_path), declaration_binding=host.predecessor.file_identity(declaration_path))


def independent_result(report, declaration_path, result):
    import r10ac_contact_frame_report
    declaration = json.loads(Path(declaration_path).read_text(encoding='utf-8-sig'))
    expected = r10ac_contact_frame_report.replay_report(report, declaration, identity)
    identity.require(result.get('controller_and_diagnostic_replay_passed') is True, 'COMBINED_REPLAY_REQUIRED')
    identity.require(host.predecessor.authority.design_audit.exact(
        result.get('r10ac_contact_frame_replay'), expected), 'INDEPENDENT_CONTACT_REPLAY')
    return expected
