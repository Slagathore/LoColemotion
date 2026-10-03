"""Audit real Godot R10AA source projection, with no physical claim."""
import argparse
import json
from pathlib import Path

import r10aa_native_component as native

ROOT, EVIDENCE = native.ROOT, native.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10aa_task_source_component_v1.json'
POSITIVE = EVIDENCE / 'r10aa-task-source-fba1105ab7fd42ccb5de3021407965c5'
WRAPPERS = ('r10aa-worker-source-check-d0c27153aa9648ae80ad292a2cc6bef6',)
PATHS = ('sdk/adapters/godot/gdscript/recovery_task_source_selector_v1.gd',
         'sdk/adapters/godot/gdscript/r10aa_partial_recovery_stage_v1.gd',
         'sdk/adapters/godot/gdscript/r10aa_partial_task_source_v1.gd',
         'tests/test_development_r10aa_task_source.py',
         'tests/test_development_r10aa_task_source.gd',
         'tests/test_development_r10aa_original_partial_source.gd',
         'tests/test_development_r10q_source_orchestration.py',
         'tests/test_development_r10k_task_source.gd',
         'sdk/conformance/r10aa_task_source_component.py')


def reconstruct():
    assert native.audit()['ok']
    assert native.read(POSITIVE / 'source_before.json') == native.read(POSITIVE / 'source_after.json')
    counts = {}
    for name, expected in (('partial-source', 162), ('original-partial-source', 99)):
        result = native.read(POSITIVE / (name + '.json'))
        execution = native.read(POSITIVE / (name + '.execution.json'))
        assert execution['exit_code'] == 0 and result['ok'] is True
        assert len(result['checks']) == expected and all(v is True for v in result['checks'].values())
        assert result['checks']['no_inserted_body'] is True
        assert result['world_build_count'] == result['solver_step_count'] == 0
        assert result['physical_acceptance_authority'] is result['release_authority'] is False
        counts[name] = expected
    for name in WRAPPERS:
        assert native.read(EVIDENCE / name / 'source.execution.json')['exit_code'] == 0
    result = dict(ok=True, interface_tests=2, checks=counts, total_checks=261,
        new_partial_source_preserves_measured_values=True,
        conflicting_tasks_refused_before_sampler_reads=True,
        original_partial_source_compatible_on_new_dll=True,
        full_worker_sequence_checked=False, launcher_reader_integrated=False,
        complete_smoke_safety_gate_passed=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    return result


def capture():
    assert not RECORD.exists()
    result = reconstruct()
    evidence = [p for folder in (POSITIVE, *(EVIDENCE / p for p in WRAPPERS))
                for p in sorted(folder.iterdir()) if p.is_file()]
    record = dict(schema_version='sporespore_r10aa_task_source_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='zero_world_source_component', question_class='development'),
        evidence_root=POSITIVE.as_posix(), native_component=native.diagnosis.binding(native.RECORD),
        source_bindings=[native.diagnosis.binding(ROOT / p) for p in PATHS],
        retained_evidence=[native.diagnosis.binding(p) for p in evidence], observed=result)
    native.write(RECORD, record)
    return result


def audit():
    record = native.read(RECORD)
    for item in record['source_bindings'] + record['retained_evidence'] + [record['native_component']]:
        native.verify(item)
    result = reconstruct()
    assert result == record['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    args = parser.parse_args()
    print('R10AA_SOURCE_COMPONENT ' + json.dumps(capture() if args.capture else audit()), flush=True)
