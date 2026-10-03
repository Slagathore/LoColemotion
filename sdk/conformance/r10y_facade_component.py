"""Audit retained R10Y walking/hold interfaces; never launch or promote physics."""
import argparse
import json
from pathlib import Path

import r10y_route_component as route

native = route.native
ROOT, EVIDENCE = route.ROOT, route.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10y_facade_component_v1.json'
FIRST = EVIDENCE / 'r10y-hold-route-interface-6e00661c694f473691f1dea91453e569'
SECOND = EVIDENCE / 'r10y-hold-route-interface-697e4f1e75f6411bb11f9a42f4b54065'
WRAPPERS = [EVIDENCE / 'r10y-facade-launch-e9842d6729ac452a85859b2d6fa4255a',
            EVIDENCE / 'r10y-facade-launch-668771252dba40889ea88207c4f8fa16']
SOURCES = [
    'sdk/adapters/godot/gdscript/' + name for name in (
        'development_recovery_cycle_stop_v1.gd',
        'development_recovery_native_walking_contacts_v1.gd',
        'development_recovery_walking_policy_v1.gd',
        'development_recovery_walking_start_v1.gd',
        'qsdk_r10f_recovery_native_locomotion_facade_v1.gd',
        'qsdk_r10f_walking_segment_evaluator_v2.gd',
        'recovery_finite_cycle_route_v1.gd',
        'r10y_stance_entry_replay_v1.gd')]
SOURCES += ['tests/' + name for name in (
    'test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd',
    'test_r10y_hold_route_interface.gd', 'test_r10y_hold_route_interface.py',
    'test_r10y_original_hold_route_interface.gd', 'test_r10y_hold_policy_report.gd')]
SOURCES += ['sdk/conformance/r10y_facade_component.py']


def observations():
    assert route.audit()['ok']
    values = {}
    for folder in (FIRST, SECOND):
        assert native.read(folder / 'source_before.json') == native.read(folder / 'source_after.json')
        native.verify(native.read(folder / 'input-binding.json'))
    for folder, name, count in ((FIRST, 'successor', 55), (SECOND, 'original', 55), (SECOND, 'policy-report', 15)):
        assert native.read(folder / (name + '.execution.json'))['exit_code'] == 0
        assert (folder / (name + '.stderr.log')).read_bytes() == b''
        value = native.read(folder / (name + '.json'))
        assert value['ok'] is True and len(value['checks']) == count
        assert all(v is True for v in value['checks'].values())
        assert value['world_build_count'] == value['solver_step_count'] == 0
        assert value['physical_acceptance_authority'] is value['release_authority'] is False
        values[name] = value
    for name in ('successor', 'original'):
        value = values[name]
        assert value['physical_route_qualified'] is False
        assert value['checks']['post_hold_cold_native_replay'] is True
        assert value['checks']['post_hold_actual_request_initial_six'] is True
        for variant in ('resume', 'ramp', 'hold', 'post_hold'):
            for check in ('actual_facade_start', 'native_identity', 'production_motor_ledger', 'shutdown'):
                assert value['checks'][variant + '_' + check] is True
        for defect in ('initial_phase', 'session_alias', 'source_clock', 'nonzero_velocity',
                       'memory_counter', 'missing_floor', 'missing_body', 'native_response', 'motor_application'):
            assert value['result']['post_hold_refusal_' + defect]['ok'] is False
    assert values['successor']['checks']['launch_authority_still_refused'] is True
    # Preserve the failed original test: its old DLL's compiled-source preflight
    # refused the changed native checkout before any session/physics execution.
    assert native.read(FIRST / 'original.execution.json')['exit_code'] == 2
    assert not (FIRST / 'original.json').exists()
    for folder, code in zip(WRAPPERS, (1, 0)):
        assert native.read(folder / 'execution.json')['exit_code'] == code
        lock = native.read(folder / 'lock.json')
        assert lock['acquired'] is True and lock['test_only'] is False
    return dict(ok=True, tests=3, total_checks=125,
        checks={name: len(value['checks']) for name, value in values.items()},
        actual_native_session_variants=['resume', 'ramp', 'hold', 'post_hold'],
        original_route_checked_on_successor_dll=True,
        post_hold_cold_command_replay_checked=True, post_hold_negative_controls=9,
        full_report_reader_checked=False, complete_launch_source_key_checked=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    result = observations()
    files = [p for folder in (FIRST, SECOND, *WRAPPERS) for p in sorted(folder.iterdir()) if p.is_file()]
    native.write(RECORD, dict(schema_version='sporespore_r10y_facade_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_native_session_interface', question_class='development'),
        route_component=native.diagnosis.binding(route.RECORD),
        source_bindings=[native.diagnosis.binding(ROOT / p) for p in SOURCES],
        retained_evidence=[native.diagnosis.binding(p) for p in files],
        initial_refusal='Original R10V fixture exited at its old DLL compiled-source preflight. '
            'A distinct fixture checks unchanged R10V selectors against the exact source-matched successor DLL; '
            'no original source key, population, result or qualification is refreshed.',
        observed=result))
    return result


def audit():
    record = native.read(RECORD)
    for item in record['source_bindings'] + record['retained_evidence'] + [record['route_component']]:
        native.verify(item)
    result = observations()
    assert result == record['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10Y_FACADE_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
