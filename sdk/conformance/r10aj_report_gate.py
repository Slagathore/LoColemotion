"""One prospectively reserved report case through the full production consumer.

Each stage has its own process and 600-second enclosing limit. Catalog identities
are single-use, even if a stage fails; a later qualification needs a new catalog.
"""
import json
from pathlib import Path
import r10aj_report_consumer as consumer

CATALOG = consumer.ROOT / 'sdk/development/r10aj_report_fixture_catalog_v4.json'
FAILURES = {
    'partial_source': 'R10AF_CONTACT_REPORT_TRACE_LINK',
    'partial_owner': 'R10AJ_RECOVERY_REPLAY_EVENT_INVALID',
    'partial_phase': 'R10AJ_RECOVERY_REPLAY_TRANSITION_STATE_CHAIN',
    'partial_energy': 'R10AJ_RECOVERY_REPLAY_TRANSITION_STATE_CHAIN',
    'walking_shutdown': 'R10AJ_ENTRY_REPLAY_POST_HOLD_FINALIZATION',
    'walking_memory': 'DEVELOPMENT_WALKING_START_INITIAL_MEMORY',
    'walking_capture': 'R10AF_CONTACT_REPORT_RECORD_POPULATION',
    'walking_missing': 'R10AJ_ENTRY_REPLAY_POST_HOLD_RETENTION',
}

def run_case(name):
    root = Path(consumer.run_case(CATALOG, name))
    result = json.loads((root / 'result.json').read_text())
    execution = json.loads((root / 'execution.json').read_text())
    assert execution['ok'] is True and execution['source_unchanged'] is True
    assert result['complete_production_python_consumer'] is True
    assert result['world_build_count'] == result['solver_step_count'] == 0
    assert result['physical_acceptance_authority'] is result['release_authority'] is False
    if name in FAILURES:
        assert result['result'] == dict(expected_refusal=True,
            consumer_error='DEVELOPMENT_PASSIVE_PROFILE_PROCESS_FAILED',
            process_returncode=1, native_failure_code=FAILURES[name]), result['result']
    child = Path(json.loads((root / 'declaration.json').read_text())['children'][0]['evidence_path'])
    assert (child / 'passive_entry_replay/stderr.txt').read_bytes() == b''
    return result
