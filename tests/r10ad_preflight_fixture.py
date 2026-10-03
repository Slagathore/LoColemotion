"""Synthetic declaration fixture for read-only R10AD preflight; no launch identity is reserved."""
import uuid
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10ad_development as identity
import r10ad_host_runtime as host


def fixture(head):
    attempt=uuid.uuid4().hex
    declaration=dict(schema_version='sporespore_development_recovery_candidate_declaration_v1',
        attempt_id=attempt,source_snapshot=dict(head=head,dirty=False,status=[],changed_file_bindings=[]),
        seed=identity.SEED,development_execution_mode=identity.SINGLE,candidate_profile=identity.reference(),
        runtime=host.expected_binding(),comparative_authority=False,baseline_reused=False,
        official_qualification=False,physical_acceptance_authority=False,release_authority=False,
        children=[dict(role=identity.ROLE,child_attempt_id=uuid.uuid4().hex,termination_nonce=uuid.uuid4().hex,
            evidence_path=(identity.EVIDENCE/('development-recovery-smoke-'+attempt)/'children'/identity.ROLE).as_posix())])
    declaration[identity.CONTEXT_KEY]=identity.context(identity.SINGLE,head,identity.reference())
    identity.validate_declaration(declaration)
    return declaration
