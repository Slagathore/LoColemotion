"""Full Python audit orchestration with explicitly synthetic external boundaries.

No production entrypoint gets a bypass. The real audit rejects these reports
without the test-only header adapter. Process observation, prepared-context
authentication, launch/claim verification and cold-replay transport are named
test doubles; contact replay, task measurement and aggregation remain real.
"""
import copy
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest import mock
import uuid

import test_r10ag_smoke_reader as headers
import r10ag_development_launch as reservation
import r10ag_native_world_authority as authority
import r10ag_retention_check as metadata
from r10ac_support_loss_diagnosis import binding, write

identity, entry, reader = headers.identity, headers.entry, headers.legacy.reader
ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE
SOURCE = EVIDENCE / 'r10ag-complete-report-8d3005c3101b4623935a09453703707d'
# The retained source identity is explicit; none of its metadata is a new run.
SOURCE_SHA = 'sha256:4c1c12410cfe8e5b20bede4e46e320f50be34c002a162ec0d46e62382d9efcdd'


def compact(path, value):
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, separators=(',', ':'), allow_nan=False); stream.write('\n')


class R10AGWorkflowAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out = EVIDENCE / ('r10ag-workflow-audit-' + uuid.uuid4().hex); cls.out.mkdir()
        print('R10AG_WORKFLOW_AUDIT_ROOT ' + str(cls.out), flush=True)
        cls.before = entry._source_snapshot(); write(cls.out / 'source-before.json', cls.before)
        assert identity.sha(SOURCE / 'worker_report.json') == SOURCE_SHA
        cls.original = json.loads((SOURCE / 'worker_report.json').read_text(encoding='utf-8'))
        cls.declared = json.loads((SOURCE / 'synthetic-declaration.json').read_text(encoding='utf-8'))
        cls.replay = json.loads((SOURCE / 'complete-replay.json').read_text(encoding='utf-8'))
        cls.chosen = headers.fixtures.candidate.selection(identity.reference())
        cls.synthetic_metadata = metadata.synthetic_fixture(cls.out, cls.before)
        sys.path.insert(0, str(ROOT / 'sdk/python'))
        write(cls.out / 'test-boundaries.json', dict(synthetic_workflow_only=True,
            source_report=binding(SOURCE / 'worker_report.json'), original_evidence_changed=False,
            original_attempt_reclassified=False, world_build_count=0, solver_step_count=0,
            physical_acceptance_authority=False, release_authority=False,
            named_test_doubles=['isolated_evidence_namespace', 'synthetic_header_adapter',
                'launch_reservation_verifier', 'native_claim_verifier', 'prepared_context_verifier',
                'cold_replay_transport_consumer'],
            real_checks=['declaration_and_header_fields', 'retained_file_and_raw_report_binding',
                'launch_receipt_consistency', 'timing_accounting', 'step_sequence_and_invariants',
                'independent_contact_replay', 'compiled_descriptor_and_task_measurement', 'diagnostic_aggregation']))

    @classmethod
    def tearDownClass(cls):
        assert identity.sha(SOURCE / 'worker_report.json') == SOURCE_SHA
        after = entry._source_snapshot(); write(cls.out / 'source-after.json', after)
        assert cls.before == after
        assert not list(EVIDENCE.glob('r10ag*consumption*.json'))

    def fixture(self, label, change=None):
        directory = self.out / label; directory.mkdir()
        namespace = directory / 'SporeSpore_Evidence'
        declaration = copy.deepcopy(self.declared)
        # Historical synthetic IDs remain fixture IDs in a new isolated namespace.
        root = namespace / ('development-recovery-smoke-' + declaration['attempt_id'])
        child = root / 'children' / identity.ROLE; child.mkdir(parents=True)
        descriptor = declaration['children'][0]; descriptor['evidence_path'] = child.as_posix()
        helper = headers.R10AGSmokeReader()
        helper.fixed = dict(declaration=declaration); helper.chosen = self.chosen
        with mock.patch.object(identity, 'EVIDENCE', namespace):
            header, _, declaration = helper.fixture()
        declaration['prepared_context_expectation'] = dict(raw_capture_binding={}, collection_identity={})
        write(root / 'declaration.json', declaration)
        report = copy.deepcopy(self.original)
        arm = report['retained_arm']; prefix = header['retained_arm']['walking_sessions'][0]
        prefix.update(session_id='synthetic-prefix', step_receipt_sha256s=[],
            evaluation=dict(schema_version='sporespore_development_smoke_walking_diagnostics_v1',
                ok=True, development_smoke_only=True, behavioral_conclusion='none'),
            completion_receipt=dict(adapter_shutdown_receipt=dict(explicit_shutdown_completed=True)))
        for key, value in header.items():
            if key not in ('retained_arm', 'solver_step_count'): report[key] = value
        count = report['solver_step_count']
        report.update(process_id=10002, global_solver_frame_count=count, after_interaction_step_count=count-272,
            coverage_complete=False, status='development_smoke_coverage_incomplete',
            diagnostic_declaration_sha256=identity.sha(root / 'declaration.json'),
            l15_prepared_context_comparison={}, explicit_worker_extra_native_readback_count=0,
            terminal_same_body_identity_receipt=dict(body_population_instance_sha256=arm['body_population_instance_sha256']))
        arm['walking_sessions'] = [prefix]
        arm['invariant_receipts'] = [dict(global_semantic_step=i, arm_id=identity.ROLE,
            body_population_instance_sha256=arm['body_population_instance_sha256'],
            all_in_run_physical_invariants_passed=True, predicates=dict(synthetic_fixture_predicate=True))
            for i in range(1, count+1)]
        arm.update(body_population_rebuild_count=0, body_transform_write_count=0,
            body_velocity_write_count=0, solver_reset_count=0, active_walking_session={}, last_walking_evaluation_failure={})
        # Keep the rejection flag in every retained artifact. Only the explicit
        # test adapter projects a temporary header for orchestration coverage.
        assert report['synthetic_test_fixture'] is True
        if change: change(report)
        raw = json.dumps(report, separators=(',', ':'), allow_nan=False)
        compact(child / 'worker_report.json', report)
        profile = self.profile(report, raw)
        with (child / 'worker.stdout.txt').open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(reader.MARKER + raw + '\n' + reader.step_profile.MARKER + json.dumps(profile) + '\n')
        envelope = copy.deepcopy(self.synthetic_metadata['envelope'])
        envelope.update(role=descriptor['role'], child_attempt_id=descriptor['child_attempt_id'],
            termination_nonce=descriptor['termination_nonce'], evidence_path=child.as_posix(), report=report)
        payload = json.loads(envelope['r10f_l15_launch_relationship']['payload_json'])
        payload['context'].update(parent_attempt_id=declaration['attempt_id'], child_attempt_id=descriptor['child_attempt_id'],
            termination_nonce=descriptor['termination_nonce'], source_commit=declaration['source_snapshot']['head'],
            authority_sha256=identity.sha(root / 'declaration.json'))
        payload['ready_receipt']['termination_nonce'] = descriptor['termination_nonce']
        payload['ready_line'] = payload['context']['ready_marker_prefix'] + json.dumps(payload['ready_receipt'], separators=(',', ':'))
        envelope['termination_ready_receipt'] = payload['ready_receipt']
        receipt = envelope['r10f_l15_launch_relationship']; receipt['payload_json'] = json.dumps(payload, separators=(',', ':'))
        encoded = receipt['payload_json'].encode(); receipt.update(payload_byte_length=len(encoded), payload_raw_sha256='sha256:'+hashlib.sha256(encoded).hexdigest())
        envelope['retained_artifact_bindings'] = {name: binding(child / name) for name in ('worker_report.json', 'worker.stdout.txt')}
        compact(child / 'child_envelope.json', envelope)
        compact(child / 'passive_entry_replay_result.json', self.replay)
        write(directory / 'fixture-scope.json', dict(synthetic_workflow_only=True, fake_worker_pid=10002,
            invariant_values_supplied_not_measured=True, timing_values_supplied_not_measured=True,
            header_retains_synthetic_rejection_flag=True, cold_replay_transport_is_a_test_double=True,
            world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False))
        return root, namespace, declaration, report

    @staticmethod
    def profile(report, raw):
        step = reader.step_profile; count = report['solver_step_count']
        counts = dict.fromkeys(('step_callback', 'between_callbacks', 'epoch_preflight', 'global_context_validation',
            'native_sampling_and_source_validation', 'energy_observation_composition', 'global_projection'), count)
        counts.update(activation_callback=1, startup_before_first_callback=1, final_report_publication=1,
            local_epoch_projection=report['after_interaction_step_count']+1)
        counts.update({'collect_step/synthetic': count, 'retain_step/synthetic': count,
            'process_step/synthetic': count, 'plan_step/synthetic': count-1})
        value = dict(schema_version='sporespore_development_step_cost_profile_v1', profile_id=step.PROFILE_ID,
            clock='Time.get_ticks_usec_monotonic_wall_time', physics_solver_time_isolated=False,
            controller_inputs_changed=False, telemetry_reduced=False, physical_acceptance_authority=False, release_authority=False,
            raw_report_sha256='sha256:'+hashlib.sha256(raw.encode()).hexdigest(), raw_report_byte_length=len(raw.encode()),
            timing=dict(ok=True, failure_code='', open_section_count=0, elapsed_us=0, accounted_us=0, unattributed_us=0,
                sections={k: dict(sample_count=n, inclusive_us=0, exclusive_us=0, maximum_us=0) for k,n in counts.items()}),
            context_cache=dict(profile_id=step.CACHE_PROFILE_ID, maximum_entries=2, observations_cached=False,
                controller_outputs_cached=False, physical_baselines_cached=False, qualification_cached=False,
                dynamic_preflight_checks_skipped=False, call_sites=dict.fromkeys(step.CACHE_CALL_SITES, count),
                hits=0, full_checks=count*2, bypasses=0, retained_entries=2))
        for key in ('source_commit', 'parent_attempt_id', 'child_attempt_id', 'arm_id', 'process_id', 'diagnostic_declaration_sha256', 'solver_step_count'):
            value[key] = report[key]
        return value

    def audit_fixture(self, fixed, *, claim_error=False, missing_controller_replay=False):
        root, namespace, declaration, report = fixed
        actual_header = reader.validate_header
        def synthetic_header(value, *args):
            self.assertIs(value.get('synthetic_test_fixture'), True)
            projected = dict(value); del projected['synthetic_test_fixture']
            return actual_header(projected, *args)
        replay = copy.deepcopy(self.replay)
        if missing_controller_replay: replay['controller_and_diagnostic_replay_passed'] = False
        actual_read = reader.read
        def read(path):
            if missing_controller_replay and path.name == 'passive_entry_replay_result.json': return replay
            return actual_read(path)
        with ExitStack() as stack:
            stack.enter_context(mock.patch.object(reader, '__file__', str(namespace.parent / 'source/sdk/conformance/development_recovery_smoke.py')))
            stack.enter_context(mock.patch.object(identity, 'EVIDENCE', namespace))
            stack.enter_context(mock.patch.object(reader, 'validate_header', side_effect=synthetic_header))
            reserved = stack.enter_context(mock.patch.object(reservation, 'verify', return_value={}))
            claimed = stack.enter_context(mock.patch.object(authority, 'verify',
                side_effect=ValueError('synthetic_claim_refused') if claim_error else None,
                return_value=report['r10ag_native_world_claim']['claim_binding']))
            context = stack.enter_context(mock.patch.object(reader.context, 'validate_worker_comparison', return_value={}))
            consumed = stack.enter_context(mock.patch.object(entry, 'consume_replay', return_value=replay))
            stack.enter_context(mock.patch.object(reader, 'read', side_effect=read))
            result = reader.audit(root)
            reserved.assert_called_once_with(root / 'declaration.json')
            claimed.assert_called_once_with(root / 'declaration.json', 10002)
            context.assert_called_once(); consumed.assert_called_once_with(root / 'children' / identity.ROLE / 'worker_report.json')
            return result

    def test_complete_python_audit_dispatch_preserves_diagnostic_negative(self):
        fixed = self.fixture('positive-dispatch'); result = self.audit_fixture(fixed)
        diagnostic = result['r10ag_contact_frame_diagnostic']
        self.assertIs(result['ok'], True); self.assertEqual(575, result['total_solver_steps'])
        self.assertFalse(result['coverage_complete']); self.assertFalse(diagnostic['all_tasks_positive'])
        self.assertTrue(diagnostic['branch_coverage_complete'])
        self.assertEqual(575, diagnostic['contact_frame_replay']['diagnostic_steps_replayed'])
        self.assertEqual('walking_not_reached', diagnostic['cells'][0]['measurement']['walking']['status'])
        self.assertIn('post_recovery_handoff', diagnostic['cells'][0])
        for name in ('causal_repair_proven', 'paired_commissioning_satisfied', 'physical_acceptance_authority', 'release_authority'):
            self.assertIs(diagnostic[name], False)
        write(self.out / 'synthetic-dispatch-result.json', dict(synthetic_workflow_only=True,
            external_boundaries_mocked=True, actual_physical_attempt=False, result=result))
        with mock.patch.object(identity, 'EVIDENCE', fixed[1]):
            with self.assertRaisesRegex(ValueError, 'SYNTHETIC_REPORT_NOT_PHYSICAL'):
                reader.validate_header(fixed[3], fixed[2]['children'][0], fixed[2], 10002)

    def test_complete_audit_refuses_supplied_failed_invariant(self):
        fixed = self.fixture('failed-invariant', lambda r: r['retained_arm']['invariant_receipts'][300]['predicates'].update(synthetic_fixture_predicate=False))
        with self.assertRaisesRegex(ValueError, 'STEP_INVARIANT'): self.audit_fixture(fixed)

    def test_complete_audit_requires_claim_and_controller_replay(self):
        fixed = self.fixture('claim-and-replay-controls')
        with self.assertRaisesRegex(ValueError, 'synthetic_claim_refused'): self.audit_fixture(fixed, claim_error=True)
        with self.assertRaisesRegex(ValueError, 'COMBINED_REPLAY_REQUIRED'): self.audit_fixture(fixed, missing_controller_replay=True)


if __name__ == '__main__': unittest.main()
