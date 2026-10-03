"""Prospective synthetic report identities at the real consumer's evidence paths.

These exact declarations are test inputs, never launch declarations. Matching a
flag alone is insufficient: the entire declaration and its raw digest must match
an immutable repository catalog. Physical launch must reject every catalog ID.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

import r10ai_development as identity

ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
DIRECTORY = ROOT / 'sdk/development'
PATTERN = 'r10ai_report_fixture_catalog_v*.json'
CASES = ['partial', 'upright', 'ready', 'timeout', 'walking',
         'partial_source', 'partial_owner', 'partial_phase', 'partial_energy',
         'walking_shutdown', 'walking_memory', 'walking_capture', 'walking_missing']


def raw(value):
    return (json.dumps(value, indent=2, allow_nan=False) + '\n').encode('utf-8')


def catalogs():
    for path in sorted(DIRECTORY.glob(PATTERN)):
        value = json.loads(path.read_text())
        assert value['schema_version'] == 'sporespore_r10ai_report_fixture_catalog_v1'
        assert value['native_worlds_permitted'] is False
        assert value['physical_execution_authorized'] is False
        assert value['physical_acceptance_authority'] is value['release_authority'] is False
        assert list(value['cases']) == CASES
        for case in value['cases'].values():
            declaration = case['declaration']
            assert declaration['report_fixture_only'] is True
            identity.validate_declaration(declaration)
            assert 'sha256:' + hashlib.sha256(raw(declaration)).hexdigest() == case['declaration_raw_sha256']
        yield path, value


def registered_declaration(path):
    """Recognize only prospectively catalogued, byte-exact synthetic inputs."""
    path = Path(path).resolve()
    for _, catalog in catalogs():
        for case in catalog['cases'].values():
            declaration = case['declaration']
            expected = EVIDENCE / ('development-recovery-smoke-' + declaration['attempt_id']) / 'declaration.json'
            if path == expected:
                return path.read_bytes() == raw(declaration)
    return False


def reserved_for_fixture(attempt_id):
    return any(case['declaration']['attempt_id'] == attempt_id
        for _, catalog in catalogs() for case in catalog['cases'].values())


def declare():
    assert not list(EVIDENCE.glob('r10ai*consumption*.json')), 'Physical population consumed'
    for path in EVIDENCE.glob('development-recovery-smoke-*/declaration.json'):
        if 'r10ai_development' in json.loads(path.read_text(encoding='utf-8-sig')):
            assert registered_declaration(path), 'Unregistered R10AI execution declaration'
    sys.path.insert(0, str(ROOT / 'tests'))
    import r10ai_preflight_fixture
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    revision = 1 + max([int(p.stem.rsplit('_v', 1)[1]) for p in DIRECTORY.glob(PATTERN)], default=0)
    target = DIRECTORY / ('r10ai_report_fixture_catalog_v' + str(revision) + '.json')
    cases = {}
    for name in CASES:
        declaration = r10ai_preflight_fixture.fixture(head)
        declaration['report_fixture_only'] = True
        cases[name] = dict(declaration=declaration,
            declaration_raw_sha256='sha256:' + hashlib.sha256(raw(declaration)).hexdigest())
    value = dict(schema_version='sporespore_r10ai_report_fixture_catalog_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                          authority_mode='prospective_zero_world_report_fixtures', question_class='development'),
        source_parent_commit=head, cases=cases, native_worlds_permitted=False,
        physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False,
        rule='Exact synthetic declarations exercise the unmodified production report paths. They never reserve a physical population. All catalog IDs must be refused by physical launch authority, even if a caller removes the fixture flag.')
    with target.open('xb') as stream: stream.write(raw(value))
    return target


if __name__ == '__main__':
    print(declare().as_posix())
