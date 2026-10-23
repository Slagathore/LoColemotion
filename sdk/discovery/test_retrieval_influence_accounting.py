"""Controls against false memory benefit from unmatched or failed exposures."""
import copy
import unittest

from retrieval_influence_accounting import exposure, exposure_pair, comparisons, window_quality, learner
from gpu_retrieval_influence import declaration


def row(correction, baseline=0., final=None):
    final = baseline+correction if final is None else final
    return dict(resolution=dict(ordered_commands=[dict(applied_correction_rad_s=correction,
        final_canonical_target_velocity_rad_s=final,baseline_canonical_target_velocity_rad_s=baseline)]*8),
        native_targets=[final]*8,baseline_native_targets=[baseline]*8)


class AccountingControls(unittest.TestCase):
    def test_equal_totals_do_not_hide_changed_triggers(self):
        a,b=[row(.1),row(0.)],[row(0.),row(.1)]
        result=exposure_pair(a,b,1/120)
        self.assertEqual(result["solver"]["absolute_integral_difference_rad"],0.)
        self.assertFalse(result["solver"]["trigger_steps_matched"])
        self.assertFalse(result["matched_influence"])

    def test_equal_triggers_do_not_hide_changed_magnitudes(self):
        self.assertFalse(exposure_pair([row(.1)],[row(.2)],1/120)["matched_influence"])
        self.assertTrue(exposure_pair([row(.1)],[row(-.1)],1/120)["matched_influence"])
        with self.assertRaises(ValueError):exposure_pair([row(.1)],[],1/120)

    def test_speed_projection_and_float32_rounding_are_measured(self):
        projected=exposure([row(.1,1.,1.)],1/120)
        self.assertGreater(projected["resolver"]["total_absolute_integral_rad"],0.)
        self.assertEqual(projected["canonical"]["total_absolute_integral_rad"],0.)
        rounded=exposure([row(1e-10,1.)],1/120)
        self.assertGreater(rounded["canonical"]["total_absolute_integral_rad"],0.)
        self.assertEqual(rounded["solver"]["total_absolute_integral_rad"],0.)

    def test_all_quality_windows_include_terminal_endpoint(self):
        positions=[[i*.2/120,0.] for i in range(61)]
        values=window_quality(positions,learner.contract())
        self.assertEqual(len(values),2)
        changed=copy.deepcopy(positions)
        changed[-1][0]+=1.
        self.assertEqual(values[0],window_quality(changed,learner.contract())[0])
        self.assertLess(window_quality(changed,learner.contract())[1],values[1])
        with self.assertRaises(ValueError):window_quality(positions[:-1],learner.contract())

    def test_failed_controls_and_unmatched_influence_withhold_benefit(self):
        c=declaration()
        metrics={m:dict(minimum_height_m=.4,maximum_tilt_rad=.1,torso_contact_steps=0,
            safe_no_actuation_steps=0,mean_window_quality_m_s=-.1) for m in c["modes"]}
        metrics["frozen"]["mean_window_quality_m_s"]=-.08
        metrics["episodic"]["mean_window_quality_m_s"]=-.06
        providers={m:dict(provider_errors=0,unexpected_fallbacks=0) for m in c["modes"]}
        rows={m:[row(.1 if m=="episodic" else 0.)] for m in c["modes"]}
        result=comparisons(metrics,providers,rows,c)
        self.assertTrue(result["frozen_favorable_in_this_group"])
        self.assertTrue(result["episodic_favorable_in_this_group"])
        self.assertFalse(result["matched_influence_memory_benefit"])
        metrics["disabled"]["torso_contact_steps"]=1
        providers["episodic"]["provider_errors"]=1
        result=comparisons(metrics,providers,rows,c)
        self.assertFalse(result["frozen_favorable_in_this_group"])
        self.assertFalse(result["episodic_favorable_in_this_group"])
        self.assertEqual(len(result["arms"]),6)


if __name__ == "__main__":
    unittest.main()
