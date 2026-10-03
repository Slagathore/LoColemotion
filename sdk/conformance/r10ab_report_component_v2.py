"""Correct source-population metadata without replacing the first R10AB receipt.

The original auditor copied a predecessor count of 1500. Its retained runs and
all source comparisons passed; the tested key actually binds 1615 files. This
successor preserves the first record/auditor and changes no tested input/result.
"""
import argparse
import json
from pathlib import Path
import r10ab_report_component as prior

native = prior.native
ROOT, EVIDENCE = prior.ROOT, prior.EVIDENCE
RECORD = ROOT / 'sdk/recovery/r10ab_report_component_v2.json'


def observations():
    result = prior.audit()
    assert result['worker_source_key_files'] == 1500
    key = native.read(prior.KEY)
    count = len(key['bound_source_files'])
    assert count == 1615 and len({r['path'] for r in key['bound_source_files']}) == count
    return dict(result, worker_source_key_files=count)


def capture():
    assert not RECORD.exists()
    result = observations()
    native.write(RECORD, dict(schema_version='sporespore_r10ab_report_component_v2',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='zero_world_report_component_metadata_correction', question_class='development'),
        predecessor_record=native.diagnosis.binding(prior.RECORD),
        predecessor_auditor=native.diagnosis.binding(Path(prior.__file__)),
        auditor=native.diagnosis.binding(Path(__file__)),
        correction=dict(field='worker_source_key_files', previous=1500, corrected=1615,
            reason='The first summary inherited a literal predecessor count; derive the count from the exact tested key.',
            physical_result_changed=False, tested_source_key_changed=False, tests_repeated=False),
        observed=result))
    return result


def audit():
    record = native.read(RECORD)
    for field in ('predecessor_record', 'predecessor_auditor', 'auditor'):
        native.verify(record[field])
    result = observations()
    assert result == record['observed']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    print('R10AB_REPORT_COMPONENT_V2 ' + json.dumps(capture() if parser.parse_args().capture else audit()), flush=True)
