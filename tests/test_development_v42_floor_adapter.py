"""V42 through the real adapter, ledger, retained memory and cold native reader."""
import copy
import hashlib
import json
import unittest

import test_development_v40_floor_adapter as rate_checks
import test_development_v41_floor_adapter as shared
import test_development_v42_stance_latch_component as component


class StanceLatchFloorAdapter(shared.UprightStanceFloorAdapter):
    policy_id = component.POLICY
    candidate_id = 'v42-stance-latch-v1'
    fixture = 'res://tests/test_development_v42_floor_adapter.gd'
    run_label = 'V42'
    receipt_schema = 'sporespore_recovery_stance_latched_upright_controller_step_receipt_v1'
    reference_mode = component.MODE

    def test_actual_constructor_adapter_and_ledger(self):
        # Reuse the actual-contact feedforward checks, not V41's contact-only
        # geometry selector. V42 changes geometry selection, never contact truth.
        rate_checks.AbsentContactReferenceFloorAdapter.test_actual_constructor_adapter_and_ledger(self)
        report = self.producer['result']['report']
        descriptor = report['configuration']['base_descriptor']
        upper = .35 * descriptor['upper_length_fraction']
        self.dimensions = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])
        rows = report['development_walking_entry']['rows']
        counts = dict(commands=0, selected_limb_inputs=0, carried_absent_limb_inputs=0,
                      present_nonbearing_limb_inputs=0, selector_transitions=0)
        previous = None
        maximum_error = 0.
        for row in rows:
            memory = row['request']['memory']
            value = row['native_output']
            # Same independent algebra used for the native component, now
            # applied to requests/receipts produced by the actual Godot route.
            mask, error = component.V42StanceLatch.reconstruct(self, row, memory, value)
            maximum_error = max(maximum_error, error)
            if previous is not None:
                self.assertEqual(previous['next_memory'], memory)
                old_mask = [limb['upright_reference_latched'] for limb in memory['support_reference']['ordered_stance_latches']]
                counts['selector_transitions'] += sum(a != b for a, b in zip(old_mask, mask))
            else:
                self.assertEqual([False]*4, [limb['upright_reference_latched'] for limb in memory['support_reference']['ordered_stance_latches']])
            for chosen, contact in zip(mask, row['request']['state']['ordered_contact_observations']):
                counts['selected_limb_inputs'] += chosen
                counts['carried_absent_limb_inputs'] += chosen and not contact['presence']
                counts['present_nonbearing_limb_inputs'] += contact['presence'] and not contact['bears_support']
            counts['commands'] += 1
            previous = value
        self.assertEqual(200, counts['commands'])
        for key in ('selected_limb_inputs', 'carried_absent_limb_inputs', 'present_nonbearing_limb_inputs', 'selector_transitions'):
            self.assertGreater(counts[key], 0, key)
        print('V42_LATCH_ADAPTER_RECONSTRUCTION', json.dumps(dict(counts,
            maximum_motor_reconstruction_error_rad_s=maximum_error,
            all_memory_links_exact=True, current_mask_comparisons_reconstructed=True,
            contacts_not_latched=True, synthetic_inputs_only=True,
            world_build_count=0, solver_step_count=0)), flush=True)

    def test_cold_reader_complete_population_and_fourteen_refusals(self):
        # Keep floor, rate and both-geometry corruption coverage unchanged.
        super().test_cold_reader_complete_population_and_fourteen_refusals()
        positive = dict(report=self.producer['result']['report'], policy_id=self.policy_id)
        rows = positive['report']['development_walking_entry']['rows']
        index = next(i for i, row in enumerate(rows) if any(
            limb['previous_latch_carry_eligible'] and not limb['precommand_contact']['presence']
            for limb in row['native_output']['actuation']['receipt']['recovery_support_plane']['stance_latch']['ordered_limbs']))
        cases = {'positive': positive}
        api = self.native_api()
        names = ('incoming_bit', 'carry_eligibility', 'previous_active', 'previous_phase', 'current_phase',
                 'contact', 'next_bit', 'source_step', 'missing_receipt', 'crossed_receipt_schema',
                 'next_memory_bit', 'missing_next_memory', 'crossed_next_memory_limb', 'next_memory_bit_kind',
                 'incoming_memory_bit', 'missing_initial_memory')
        for name in names:
            item = copy.deepcopy(positive)
            row = item['report']['development_walking_entry']['rows'][index]
            act = row['native_output']['actuation']
            support = act['receipt']['recovery_support_plane']
            latch = support['stance_latch']
            limb = next(limb for limb in latch['ordered_limbs'] if limb['previous_latch_carry_eligible'] and not limb['precommand_contact']['presence'])
            memory = row['native_output']['next_memory']['support_reference']
            if name == 'incoming_bit': limb['incoming_upright_reference_latched'] = False
            elif name == 'carry_eligibility': limb['previous_latch_carry_eligible'] = False
            elif name == 'previous_active': limb['previous_wave_active'] = False
            elif name == 'previous_phase': limb['previous_scheduled_phase_step'] += 1
            elif name == 'current_phase': limb['current_scheduled_phase_step'] += 1
            elif name == 'contact': limb['precommand_contact']['presence'] = True
            elif name == 'next_bit': limb['next_upright_reference_latched'] = False
            elif name == 'source_step': latch['source_semantic_step'] += 1
            elif name == 'missing_receipt': del support['stance_latch']
            elif name == 'crossed_receipt_schema': act['receipt']['schema_version'] = 'sporespore_recovery_upright_stance_controller_step_receipt_v1'
            elif name == 'next_memory_bit': memory['ordered_stance_latches'][0]['upright_reference_latched'] = not memory['ordered_stance_latches'][0]['upright_reference_latched']
            elif name == 'missing_next_memory': del memory['ordered_stance_latches']
            elif name == 'crossed_next_memory_limb': memory['ordered_stance_latches'][0]['limb_id'] = 'rear_right'
            elif name == 'next_memory_bit_kind': memory['ordered_stance_latches'][0]['upright_reference_latched'] = 1
            elif name == 'incoming_memory_bit':
                incoming = row['request']['memory']['support_reference']['ordered_stance_latches'][0]
                incoming['upright_reference_latched'] = not incoming['upright_reference_latched']
            else:
                del item['report']['development_walking_entry']['rows'][0]['request']['memory']['support_reference']['ordered_stance_latches']
            # Rehash altered receipts. A self-consistent advertised digest must
            # not bypass exact native-output or memory-chain reconstruction.
            act['receipt_sha256'] = 'sha256:'+hashlib.sha256(api.canonical(act['receipt'])).hexdigest()
            cases[name] = item
        path = self.root/'stance_latch_reader_inputs.json'
        with path.open('x', encoding='utf-8') as stream:
            json.dump(cases, stream, separators=(',', ':'), allow_nan=False)
        run = self._run_retained(self.fixture, ['--', str(path)], 'stance_latch_cold_reader', 90)
        results = shared.marker(run, 'V34_FLOOR_READER ')
        self.assertEqual(17, len(results))
        self.assertTrue(results['positive']['ok'])
        self.assertEqual(200, results['positive']['replayed_walking_steps'])
        for name, result in results.items():
            if name == 'positive': continue
            expected = ('READER_MEMORY_CHAIN' if name == 'incoming_memory_bit' else
                        'READER_RAW_NATIVE_RESPONSE_MISMATCH' if name == 'missing_initial_memory' else
                        'READER_NATIVE_OUTPUT_MISMATCH')
            self.assertFalse(result['ok'], (name, result))
            self.assertEqual('DEVELOPMENT_WALKING_ENTRY_'+expected, result['failure_code'])
        print('V42_LATCH_COLD_READER', json.dumps(dict(positive_steps=200,
            refused_cases={name:r['failure_code'] for name, r in results.items() if name != 'positive'},
            changed_receipts_rehashed=True, world_build_count=0, solver_step_count=0)), flush=True)


def load_tests(loader, _tests, _pattern):
    # The unchanged 44-case legacy differential has its own mandatory stage.
    # Keep this native producer/reader stage within the existing 180-second
    # bound without dropping coverage or constructing its fixture twice.
    return unittest.TestSuite(StanceLatchFloorAdapter(name) for name in
        loader.getTestCaseNames(StanceLatchFloorAdapter)
        if name != 'test_legacy_source_suite_has_no_new_failures')


if __name__ == '__main__':
    unittest.main()
