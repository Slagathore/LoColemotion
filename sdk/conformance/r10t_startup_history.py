"""Replay R10S evidence while resolving one historical source to its exact archive."""
import json
from pathlib import Path
from unittest.mock import patch
import r10s_startup_component as original
ROOT=Path(__file__).resolve().parents[2]
BINDING=ROOT/'sdk/recovery/r10t_startup_history_binding_v1.json'


def audit(*,cold=True):
    binding=original.read(BINDING)
    for name in ['original_record','source_snapshot','retained_source']:
        original.verify(binding[name])
    item=binding['original_source_binding']
    record=original.read(original.RECORD)
    original.require(item in record['sources'] and binding['original_record']['path']==original.RECORD.as_posix(),'HISTORY_RECORD')
    original.require(binding['retained_source']['raw_sha256']==item['raw_sha256']
        and binding['retained_source']['byte_length']==item['byte_length'],'HISTORY_EXACT_BYTES')
    actual_verify=original.verify
    def verify_with_history(value):
        if value==item:
            return actual_verify(binding['retained_source'])
        return actual_verify(value)
    # The old auditor, record, runtime, requests and response bytes stay exact.
    # Only this historical provenance path resolves to the retained old bytes.
    with patch.object(original,'verify',verify_with_history):
        return original.audit(cold=cold)
