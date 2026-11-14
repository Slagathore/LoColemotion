"""Aggregation refuses corrupted metrics and preserves a valid negative screen."""
import copy
import unittest

from check_coupled_contact_response import aggregate, native_velocity


def fixture():
    rows = []
    for body in range(3):
        predictions = {}
        for name, error in (('free', 1.), ('feet', 1.), ('all', .5)):
            predictions[name] = dict(velocity=[0.,0.,0.,error,0.,0.]+[0.]*8, converged=True,
                kkt_residual=0., root_angular_error_rad_s=error, root_linear_error_m_s=0., joint_velocity_error_rad_s=0.)
        rows.append(dict(batch=str(body), cell_id=str(body), outer_step=0, native_velocity=[0.]*14,
            predictions=predictions, checks=dict(geometry_error_m=0., kinetic_error_j=0.)))
    plan = dict(expected_samples=3, variants=['free','feet','all'], parameters=dict(kkt_tolerance=1e-9),
        validation=dict(maximum_geometry_error_m=2e-6, maximum_kinetic_error_j=1e-8, all_predictions_must_converge=True),
        input=dict(bodies=3), criterion=dict(minimum_relative_error_reduction_against_feet_per_body=.2))
    result = dict(maximum_geometry_error_m=0., maximum_kinetic_error_j=0., summaries={})
    for row in rows:
        result['summaries'][row['batch']] = {k:dict(samples=1, converged=1,
            maximum_root_angular_error_rad_s=v['root_angular_error_rad_s'], mean_root_angular_error_rad_s=v['root_angular_error_rad_s'],
            mean_root_linear_error_m_s=0., mean_joint_velocity_error_rad_s=0.) for k,v in row['predictions'].items()}
    return rows, plan, result, [(str(i),str(i),0) for i in range(3)]


class ResponseReaderControls(unittest.TestCase):
    def test_positive_screen_and_scalar_rotation(self):
        self.assertTrue(aggregate(*fixture())['retained_state_screen_passed'])
        row=dict(qpos=[0.,0.,0.,.5,.5,.5,.5]+[0.]*8, qvel=[1.,2.,3.,1.,0.,0.]+[0.]*8)
        self.assertEqual(native_velocity(row)[:6], [1.,3.,-2.,0.,0.,-1.])

    def test_refuses_changed_norm_and_nonfinite_prediction(self):
        for corrupt in (lambda p:p.update(root_angular_error_rad_s=.1), lambda p:p['velocity'].__setitem__(3,float('nan'))):
            args=fixture(); corrupt(args[0][0]['predictions']['all'])
            with self.assertRaises(ValueError): aggregate(*args)
        args=fixture(); args[0][0]['checks']['geometry_error_m']=float('nan')
        with self.assertRaises(ValueError): aggregate(*args)

    def test_refuses_missing_reordered_and_duplicate_samples(self):
        for mutate in (lambda rows:rows.pop(), lambda rows:rows.reverse(), lambda rows:rows.__setitem__(1,copy.deepcopy(rows[0]))):
            args=fixture(); mutate(args[0])
            with self.assertRaises(ValueError): aggregate(*args)

    def test_refuses_forged_convergence_and_summary(self):
        for mutate in (lambda a:a[0][0]['predictions']['all'].update(kkt_residual=1.),
                       lambda a:a[2]['summaries']['0']['all'].update(mean_root_angular_error_rad_s=0.)):
            args=fixture(); mutate(args)
            with self.assertRaises(ValueError): aggregate(*args)

    def test_valid_nonconvergence_fails_screen(self):
        args=fixture(); args[0][0]['predictions']['all'].update(converged=False,kkt_residual=1.)
        args[2]['summaries']['0']['all']['converged']=0
        result=aggregate(*args)
        self.assertFalse(result['retained_state_screen_passed']); self.assertFalse(result['all_predictions_converged'])

    def test_valid_failed_threshold_and_geometry_remain_failures(self):
        for change in ('threshold','geometry'):
            args=fixture()
            if change=='threshold': args[1]['criterion']['minimum_relative_error_reduction_against_feet_per_body']=.6
            else:
                args[0][0]['checks']['geometry_error_m']=3e-6; args[2]['maximum_geometry_error_m']=3e-6
            self.assertFalse(aggregate(*args)['retained_state_screen_passed'])


if __name__ == '__main__': unittest.main()
