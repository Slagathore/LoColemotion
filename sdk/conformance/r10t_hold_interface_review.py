"""Close the native hold study, retaining every probe defect and original result."""
import argparse
import json
import uuid

import recovery_post_completion_hold_probe as probe
from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify

RECORD = ROOT/'sdk/recovery/r10t_post_recovery_hold_interface_review_v1.json'
FINAL = EVIDENCE/'post-completion-hold-interface-87c57f9850d345e48d87402256561673'
PARSE = EVIDENCE/'post-completion-hold-interface-b6050ce2feb340ddb42b301f9a31ada4'
REJECTED = [EVIDENCE/('post-completion-hold-interface-'+s) for s in [
    '7be56ef29cb74cd8b3b34aa2d383dfef', 'f2b79966ea00431582da0a0a2e3c9c5e', '8c4f080fd57a4eff92b40a1bfaf49ae3']]
DECODERS = [EVIDENCE/('post-completion-hold-decoder-'+s) for s in [
    '8bc2237075a4448aa3bc3c7524c9f30e', '2c79c5d06f7240f5bb781706e8df1755']]


def observed():
    final = probe.audit(FINAL)
    assert not (PARSE/'native_calls.jsonl').exists()
    assert 'Parse Error' in (PARSE/'probe.stderr.txt').read_text(encoding='utf-8')
    assert read(PARSE/'probe.execution.json')['returncode'] == 1
    native_rows = [json.loads(line) for line in (FINAL/'native_calls.jsonl').read_text(encoding='utf-8').splitlines()]
    for run in REJECTED:
        original = read(run/'result.json')
        assert original['ok'] is False and original['input_raw_sha256'] == read(FINAL/'result.json')['input_raw_sha256']
        assert read(run/'probe.execution.json')['returncode'] == 1
        assert len(original['cases']) == 4
        for case in original['cases']:
            assert case['ok'] is False and case['native_commands'] == 240
            assert case['checks']['crossed_body_clock_refused'] is False
            assert all(value for key, value in case['checks'].items() if key != 'crossed_body_clock_refused')
        rows = (json.loads(line) for line in (run/'native_calls.jsonl').read_text(encoding='utf-8').splitlines())
        for before, after in zip(rows, native_rows, strict=True):
            # Correcting the checker changed no native request or original response.
            assert before == {key:value for key,value in after.items() if key != 'stateless_host_value'}
    for run in [PARSE, *REJECTED, FINAL]:
        assert read(run/'source_unchanged.json')['unchanged']
        for item in read(run/'retention_manifest.json')['files']:
            verify(item)
    decoder_results = []
    for run in DECODERS:
        assert read(run/'decoder.execution.json')['returncode'] == 0
        lines = [json.loads(line.split(' ',1)[1]) for line in (run/'decoder.stdout.txt').read_text(encoding='utf-8').splitlines()
                 if line.startswith('DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY ')]
        assert len(lines) == 1 and lines[0]['ok'] and lines[0]['native_policy_calls'] == 0
        decoder_results.append(lines[0])
    assert decoder_results[1]['corrected_memory_comparison'] and decoder_results[1]['changed_counter_refused']
    return dict(ok=True, corrected_probe=final, original_probe_runs=5, native_probe_runs=4,
        total_native_hold_commands_including_checker_diagnostics=3840,
        total_stateless_comparisons_including_checker_diagnostics=3840,
        original_failed_probe_outputs_preserved=True, corrected_native_requests_and_outputs_unchanged=True,
        prior_probe_defects=['GDScript Dictionary type inference prevented parsing before policy calls',
            'The checker required outer ok false and missed safe_no_actuation FRAME_INVALID',
            'The memory checker compared 0.0 host counters with native integer 0 as different types'],
        native_controller_defect_found=False, legacy_host_parser_preserved=True,
        physical_dynamics_prediction=False, successor_implementation_selected=False,
        next_permitted_stage='distinct_bounded_upright_speed_handoff_successor_design', **probe.CLAIMS)


def create():
    assert not RECORD.exists()
    result = observed()
    out = EVIDENCE/('r10t-hold-interface-review-'+uuid.uuid4().hex)
    out.mkdir()
    files = [bind(run/'retention_manifest.json') for run in [PARSE,*REJECTED,FINAL]]
    files += [bind(path) for run in DECODERS for path in sorted(run.iterdir()) if path.is_file()]
    probe.write(out/'retained-evidence-manifest.json', dict(files=files))
    probe.write(RECORD, dict(schema_version='sporespore_r10t_hold_interface_review_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='retained_zero_world_native_interface_review', question_class='development'),
        auditor=bind(__file__), bindings=[bind(probe.STUDY), bind(probe.SCRIPT), bind(probe.__file__),
            bind(ROOT/'tests/test_post_completion_hold_refusal_decoding.gd')],
        evidence_manifest=bind(out/'retained-evidence-manifest.json'),
        interpretation='The corrected full probe passes. Previous failed probe outputs retain their original classification as checker or parser failures. All original native requests and responses match the corrected execution. No held-out evidence or physical controller behavior was changed or measured.',
        observed=result, claim_boundary=probe.CLAIMS))
    return dict(record=bind(RECORD), **result)


def audit():
    record = read(RECORD)
    assert record['claim_boundary'] == probe.CLAIMS
    for item in record['bindings']+[record['auditor'], record['evidence_manifest']]: verify(item)
    for item in read(record['evidence_manifest']['path'])['files']: verify(item)
    assert record['observed'] == observed()
    return dict(ok=True, record=bind(RECORD), native_commands=960, physical_worlds=0, sdk1_score='14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    print('R10T_HOLD_INTERFACE_REVIEW '+json.dumps(create() if args.create else audit()))
