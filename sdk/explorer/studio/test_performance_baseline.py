import unittest
from build_performance_baseline import summarize


class ClockInterpretation(unittest.TestCase):
    def test_startup_is_not_misreported_as_native_loop_slowdown(self):
        receipt={'preflight':{'elapsed_s':3},'physical':{'elapsed_s':120,'completed':{'outcome':'positive'},'hello':{},},'runtime':{}}
        frames=[{'frame_index':1200,'simulation_time_s':10,'physics_wall_time_s':10,'applied_impulses':[]}]
        row=summarize(receipt,frames)
        self.assertEqual(row['native_loop_realtime_factor'],1)
        self.assertEqual(row['outside_reported_native_loop_seconds'],110)
        self.assertEqual(row['published_frames'],1)
        self.assertEqual(row['solver_steps'],1200)

    def test_crossed_or_zero_clocks_are_rejected(self):
        receipt={'physical':{'elapsed_s':5}}
        for loop in [0,-1,6]:
            with self.assertRaises(ValueError):summarize(receipt,[{'simulation_time_s':1,'physics_wall_time_s':loop}])


if __name__=='__main__':unittest.main(verbosity=2)
