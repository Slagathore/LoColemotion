"""Close a quiescent sweep manifest after preserving a self-captured audit log."""
import argparse
import copy
import json
from pathlib import Path
import uuid
import r10t_remaining_stage_sweep as prior

base = prior.base
ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10t_remaining_stage_sweep_component_v2.json'


def audit(record):
    base.verify(record['predecessor'])
    original = base.read(record['predecessor']['path'])
    expected = copy.deepcopy(original)
    for key in ['schema_version', 'auditor', 'manifest', 'predecessor', 'retention_correction']:
        expected[key] = record[key]
    assert expected == record
    old_files = base.read(original['manifest']['path'])['files']
    changed = [item for item in old_files if base.bind(item['path']) != item]
    assert len(changed) == 1 and changed[0]['path'].endswith('/closure-audit.stdout.json')
    assert changed[0]['byte_length'] == 0
    assert changed[0]['raw_sha256'] == 'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    assert record['retention_correction']['completed_audit_output'] == base.bind(changed[0]['path'])
    assert record['retention_correction']['original_manifest_valid_after_stdout_completion'] is False
    assert record['retention_correction']['original_results_reclassified'] is False
    # The original observation auditor still validates all stages and source bytes.
    # Only the distinct manifest now inventories the completed, quiescent files.
    return prior.audit(record, False)


def create():
    assert not RECORD.exists()
    original = base.read(prior.RECORD)
    directory = EVIDENCE/('r10t-remaining-retention-closure-'+uuid.uuid4().hex); directory.mkdir()
    old_files = base.read(original['manifest']['path'])['files']
    manifest = directory/'manifest.json'
    base.write_new(manifest, dict(files=[base.bind(item['path']) for item in old_files]))
    record = copy.deepcopy(original)
    record.update(schema_version='sporespore_r10t_remaining_stage_sweep_component_v2',
        auditor=base.bind(__file__), manifest=base.bind(manifest), predecessor=base.bind(prior.RECORD),
        retention_correction=dict(
            reason='The first manifest captured redirected audit stdout while empty. Audit completion populated that file after closure. Preserve the first closure and final stdout; inventory the completed files in this distinct successor.',
            completed_audit_output=base.bind(Path(original['run_root'])/'closure-audit.stdout.json'),
            original_manifest_valid_after_stdout_completion=False, original_results_reclassified=False))
    audit(record); base.write_new(RECORD, record)
    return audit(record)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    result = create() if args.create else audit(base.read(RECORD))
    print(json.dumps({k:v for k,v in result.items() if k != 'stages'}))
