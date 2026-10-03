"""Synthetic v7 launch metadata tests the actual compact writer; no process launch."""
import hashlib
import json
import mmap
import subprocess
import uuid

import development_passive_entry_profile as source
import r10af_host_runtime as host
import r10t_route_integration_component as base
from r10ac_support_loss_diagnosis import binding

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RUN = EVIDENCE / 'development-recovery-smoke-2e83ffbb9cb84fb1ba1dfc2c76886f37'


def synthetic_fixture(directory, before):
    envelope_path = RUN / 'children/kick_passive_recovery_resume/child_envelope.json'
    original = binding(envelope_path)
    # Only use the old envelope's structural shape. The source bytes are immutable.
    with envelope_path.open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as raw:
        first = raw.find(b'\n  "report":'); last = raw.find(b'\n  "retained_artifact_bindings":')
        assert 0 < first < last
        metadata = json.loads(raw[:first] + b'\n  "report": null,' + raw[last:])
    runtime = host.expected_binding()
    host.bind_runtime(runtime['images']['godot_console']['path'], runtime['images']['powershell_host']['path'])
    receipt = metadata['r10f_l15_launch_relationship']
    payload = json.loads(receipt['payload_json'])
    context = payload['context']
    context.update(parent_attempt_id=uuid.uuid4().hex, child_attempt_id=uuid.uuid4().hex,
        termination_nonce=uuid.uuid4().hex, source_commit=before['head'],
        authority_sha256='sha256:' + hashlib.sha256(b'R10AF synthetic retention fixture; no authority').hexdigest(),
        root_image=runtime['images']['godot_console'], worker_image=runtime['images']['godot_engine'])
    metadata.update(child_attempt_id=context['child_attempt_id'], termination_nonce=context['termination_nonce'],
        evidence_path=directory.as_posix(), retained_artifact_bindings={}, process_id=10001, worker_process_id=10002)
    payload.update(root_process_id=10001, worker_process_id=10002)
    payload['process_chain'][0].update(process_id=10002, parent_process_id=10001,
        executable_path=context['worker_image']['path'])
    payload['process_chain'][1].update(process_id=10001, parent_process_id=10000,
        executable_path=context['root_image']['path'])
    payload['ready_receipt'].update(process_id=10002, termination_nonce=context['termination_nonce'])
    payload['ready_line'] = context['ready_marker_prefix'] + json.dumps(payload['ready_receipt'], separators=(',', ':'))
    metadata['termination_ready_receipt'] = payload['ready_receipt']
    receipt['payload_json'] = json.dumps(payload, separators=(',', ':'))
    encoded = receipt['payload_json'].encode()
    receipt['payload_byte_length'] = len(encoded)
    receipt['payload_raw_sha256'] = 'sha256:' + hashlib.sha256(encoded).hexdigest()
    assert binding(envelope_path) == original
    return dict(envelope=metadata, context=context, runtime=runtime,
        provenance='Entire output is a synthetic fixture derived from an exposed metadata shape. Fresh fixture identities, synthetic process IDs and exact v7 image bindings. No process observed or launched; no original evidence changed.',
        original_envelope=original, original_attempt_reclassified=False,
        synthetic_launch_metadata=True, world_build_count=0, solver_step_count=0)


def main():
    directory = EVIDENCE / ('r10af-retention-check-' + uuid.uuid4().hex); directory.mkdir()
    print('R10AF_RETENTION_CHECK ' + str(directory), flush=True)
    before = source._source_snapshot(); base.write_new(directory / 'source_before.json', before)
    fixture = directory / 'fixture.json'
    base.write_new(fixture, synthetic_fixture(directory, before))
    command = [host.expected_binding()['images']['powershell_host']['path'], '-NoLogo', '-NoProfile',
        '-NonInteractive', '-File', str(ROOT / 'tests/test_r10af_compact_child_retention.ps1'),
        '-Fixture', str(fixture), '-OutputRoot', str(directory)]
    with (directory / 'stdout.json').open('xb') as out, (directory / 'stderr.txt').open('xb') as err:
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, timeout=120,
                creationflags=subprocess.CREATE_NO_WINDOW)
        except subprocess.TimeoutExpired:
            base.write_new(directory / 'execution.json', dict(command=command, timed_out=True,
                direct_process_killed_and_reaped=True, world_build_count=0, solver_step_count=0))
            raise
    after = source._source_snapshot(); base.write_new(directory / 'source_after.json', after)
    receipt = dict(command=command, exit_code=result.returncode, timed_out=False,
        source_unchanged=before == after, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
    base.write_new(directory / 'execution.json', receipt)
    assert before == after
    assert (directory / 'stderr.txt').read_bytes() == b''
    print(json.dumps(receipt)); return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
