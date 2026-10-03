"""Verify the retained CodeLapse gate refusal without rerunning or regrading it."""
import base64
import json

from r10s_launch_component import ROOT, bind, read, verify

RECORD = ROOT/'sdk/recovery/r10s_phase245_source_drift_refusal_v1.json'


def audit():
    record = read(RECORD)
    assert record['schema_version'] == 'sporespore_r10s_phase245_source_drift_refusal_v1'
    for item in record['bindings'] + [record['auditor'], record['evidence_manifest']]:
        verify(item)
    manifest = read(record['evidence_manifest']['path'])
    for item in manifest['files']:
        verify(item)
    from pathlib import Path
    run, outer, preparation = (Path(record[k]) for k in ['gate_root', 'outer_root', 'preparation_root'])
    supervisor = read(run/'supervisor_result.json')
    execution = read(outer/'execution.json')
    assert supervisor['source_snapshot'] == dict(head=record['source_commit'], dirty=False,
        status=[], changed_file_bindings=[])
    assert supervisor['ok'] is False and supervisor['physical_attempt_started'] is False
    assert supervisor['failure_code'] == 'SMOKE_SAFETY_GATE_FAILED:r10s_preparation_report'
    stages = supervisor['safety_stages']
    assert len(stages) == 26 and all(s['passed'] is True for s in stages[:-1])
    assert sum(s['test_count'] for s in stages[:-1]) == 112
    failed = stages[-1]
    assert failed['id'] == 'r10s_preparation_report' and failed['passed'] is False
    assert failed['timed_out'] is False and failed['exit_code'] == 1 and failed['test_count'] == 0
    assert 'R10S_PREPARATION_SOURCE_DRIFT' in (run/failed['stderr']).read_text(encoding='utf-8')
    for stage in stages:
        for stream in ['stdout', 'stderr']:
            assert bind(run/stage[stream])['raw_sha256'] == 'sha256:' + stage[stream+'_sha256']
    before, after = read(preparation/'source_before.json'), read(preparation/'setup_source_after.json')
    assert before['head'] == after['head'] == record['source_commit']
    assert before['status'] == '' and after['status'] == '?? .snapshots/\x00'
    assert [k for k in before if before[k] != after[k]] == ['status', 'changed_files']
    assert len(before['changed_files']) == 0 and len(after['changed_files']) == 1
    snapshot = record['retained_snapshot_index']
    verify(snapshot)
    change = after['changed_files'][0]
    assert change['path'] == '.snapshots/index.json' and change['deleted'] is False
    assert change['raw_sha256'] == snapshot['raw_sha256']
    assert base64.b64decode(change['replacement_base64'], validate=True) == Path(snapshot['path']).read_bytes()
    assert execution['source_commit_after'] == record['source_commit']
    assert execution['source_status_after'] == ['?? .snapshots/'] and execution['exit_code'] == 1
    assert execution['physical_consumption_record_exists'] is False
    assert read(record['retained_snapshot_index']['path']) == dict(snapshots=[], currentIndex=-1, activeSnapshotId=None)
    assert record['physical_identity_consumed'] is False and record['original_result_reclassified'] is False
    assert record['physical_acceptance_authority'] is False and record['release_authority'] is False
    return dict(ok=True, classification='valid_zero_world_source_drift_refusal',
        passed_stages=25, passed_tests=112, physical_attempt_started=False,
        physical_identity_consumed=False, original_result_reclassified=False,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print('R10S_SOURCE_DRIFT_REFUSAL ' + json.dumps(audit()))
