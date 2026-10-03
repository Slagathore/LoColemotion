"""Audit the closed R10T record using its exact archived candidate selector.

This is read-only historical provenance, never a live candidate selector or a
qualification for R10U. The original failure, reservation and closure stay exact.
"""
import hashlib
import json
from pathlib import Path
import sys
import types
from unittest.mock import patch

import r10u_development as development
import r10t_initial_invalid_closure as original


def historical_selector(record):
    archive = record['source_archive']
    original.base.verify(archive['key'])
    original.base.verify(archive['snapshot'])
    key = original.base.read(archive['key']['path'])
    directory = Path(archive['directory']).resolve()
    if not directory.is_relative_to(development.EVIDENCE.resolve()):
        raise ValueError('R10U_HISTORY_ARCHIVE_ROOT')
    paths = {}
    for item in key['bound_source_files']:
        relative = Path(item['path'])
        source = (directory/relative).resolve()
        canonical = (development.ROOT/relative).resolve()
        if not source.is_relative_to(directory) or not canonical.is_relative_to(development.ROOT):
            raise ValueError('R10U_HISTORY_ARCHIVE_ESCAPE')
        if original.base.bind(source)['raw_sha256'] != item['raw_sha256']:
            raise ValueError('R10U_HISTORY_ARCHIVE_BYTES')
        if canonical in paths:
            raise ValueError('R10U_HISTORY_DUPLICATE_SOURCE')
        paths[canonical] = source
    name = 'development_recovery_candidate'
    canonical = development.ROOT/'sdk/conformance/development_recovery_candidate.py'
    module = types.ModuleType(name)
    module.__file__ = str(canonical)
    # The old code resolves its original canonical paths. Only the source hashes
    # below are read from the verified complete archive, never from a successor.
    exec(compile(paths[canonical.resolve()].read_bytes(), str(canonical), 'exec'), module.__dict__)
    live_sha = module.sha
    def archived_sha(path):
        path = Path(path).resolve()
        return live_sha(paths.get(path,path))
    module.sha = archived_sha
    return module, len(paths)


def audit():
    development.require(development.sha(development.DESIGN) == development.DESIGN_SHA, 'HISTORY_DESIGN')
    binding = development.read(development.DESIGN)['predecessor_closure']
    original.base.verify(binding)
    record = original.base.read(binding['path'])
    module, count = historical_selector(record)
    # A separate interpreter invocation uses this scope only for the old audit.
    # It restores the live module afterward and neither launches nor regrades.
    with patch.dict(sys.modules, {'development_recovery_candidate':module}):
        result = original.audit(record)
    assert result['original_attempt_classification'] == 'consumed_infrastructure_invalid'
    assert result['original_attempt_reclassified'] is False and result['r10t_development_chain_closed']
    return dict(ok=True, ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
        authority_mode='read_only_historical_source_reconstruction',question_class='development'),
        predecessor_closure=binding, archived_sources=count, original_audit=result,
        live_source_qualified=False, r10u_execution_authorized=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    print(json.dumps(audit()))
