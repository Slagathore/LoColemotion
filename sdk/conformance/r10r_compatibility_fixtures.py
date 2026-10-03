"""Exact original fixture bytes, replayed on the separately selected R10R DLL."""
from pathlib import Path
import development_recovery_candidate as candidate
import development_passive_entry_profile as entry

def fixture_binding():
    record = candidate.read(candidate.ROOT / 'sdk/development/r10r_compatibility_fixture_contract_v1.json')
    source = record['source_runtime_binding']
    candidate.require(candidate.sha(candidate.ROOT / source['path']) == source['raw_sha256'], 'R10R_COMPATIBILITY_SOURCE_BINDING')
    original = candidate.read(candidate.ROOT / source['path'])['compiled_fixtures']
    candidate.require(original == record['compiled_fixtures'] and entry.runtime.file_identity(Path(original['path'])) == original, 'R10R_COMPATIBILITY_FIXTURE_BYTES')
    return original
