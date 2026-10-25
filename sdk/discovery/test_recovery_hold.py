"""Real-core hold transition and refusal controls; no native worlds."""
import copy
import os
from pathlib import Path
import unittest
from unittest.mock import patch
from audit_gpu_batch_execution import read_jsonl,same_bits
from causal_force_native_task import ROOT,read,bridge,controller_contract,frozen_model,declaration
from causal_force_policy import make_profile,HANDOFF
from recovery_hold_control import HoldForceController,terminal_error
from recovery_hold_composition import hold_motion_command,compose_recovery_step


class RecoveryHoldControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core=bridge.LocomotionCore(Path(os.environ["QUADRUPED_TEST_CORE"]))
        closure=read(ROOT/"sdk/discovery/causal_force_native_closure_v1.json")
        folder=ROOT.parent/"SporeSpore_Evidence"/closure["attempt_id"]/"physical/force_reference_left_075_train_001"
        cls.compiled=read(folder/"compiled.json");cls.inputs=read(folder/"inputs.json")
        cls.rows=list(read_jsonl(folder/"controller.jsonl"));cls.profile=make_profile(cls.compiled,cls.inputs)

    def host(self):
        model=frozen_model(self.core)
        host=HoldForceController(self.core,self.compiled,controller_contract(declaration(),model),
            model,"force_reference_left_075_train_001",self.profile)
        self.addCleanup(host.close)
        return host

    def step(self,host,i):
        old=self.rows[i]
        return host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))

    def prefix(self):
        host=self.host()
        for i in range(HANDOFF):self.step(host,i)
        return host

    def test_hold_command_changes_only_declared_motion_fields(self):
        old=bridge._motion_command(60,"clocked");new=hold_motion_command(60,"clocked")
        self.assertEqual({k for k in old if old[k]!=new[k]},
            {"speed_class","gait_amplitude","desired_planar_velocity_task_m_s"})
        self.assertEqual(new["desired_planar_velocity_task_m_s"],dict(x=0.,y=0.,z=0.))
        self.assertEqual(new["gait_amplitude"],0.);self.assertEqual(new["speed_class"],"hold")

    def test_hold_command_rejects_wrong_clock_or_phase(self):
        for step,phase in ((59,"clocked"),(True,"clocked"),(60.0,"clocked"),(60,"contact_gated")):
            with self.assertRaises(ValueError):hold_motion_command(step,phase)

    def test_full_prefix_reproduces_retained_controls(self):
        host=self.host()
        for i in range(HANDOFF):
            row=self.step(host,i)
            self.assertTrue(all(same_bits(v,self.rows[i][k]) for k,v in row.items()))
            self.assertNotIn("recovery_hold",row)

    def test_walk_composition_matches_frozen_adapter(self):
        host=self.prefix();old=self.rows[60];memory=copy.deepcopy(host.composition_memory)
        args=(host.context,old["output"]["actuation"],old["stability"],old["kinematics"],
            bridge._ordered_limb_steps(host.memory,host.context.morphology["ordered_limb_ids"]))
        original=bridge.compose_bw19v_step(*args,host.composition_memory)
        successor=compose_recovery_step(*args,memory,bridge._motion_command(60,"clocked"))
        self.assertTrue(same_bits(original,successor));self.assertEqual(vars(memory),vars(host.composition_memory))

    def test_mismatched_composition_command_refused_before_core_call(self):
        host=self.prefix();old=self.rows[60]
        args=(host.context,old["output"]["actuation"],old["stability"],old["kinematics"],
            bridge._ordered_limb_steps(host.memory,host.context.morphology["ordered_limb_ids"]))
        changes=({"gait_amplitude":1.},{"valid_from_step":61},{"speed_class":"run"},
            {"desired_planar_velocity_task_m_s":dict(x=.2,y=0.,z=0.)})
        with patch.object(self.core,"plan_scheduled_load_transfer_v3",side_effect=AssertionError("must reject first")):
            for change in changes:
                command=hold_motion_command(60,"clocked");command.update(change)
                with self.assertRaises(ValueError):compose_recovery_step(*args,copy.deepcopy(host.composition_memory),command)

    def test_handoff_aligns_motion_and_support_plan(self):
        host=self.prefix()
        with patch.object(self.core,"plan_scheduled_load_transfer_v3",wraps=self.core.plan_scheduled_load_transfer_v3) as planned:
            row=self.step(host,60)
        self.assertIsNone(terminal_error(row));self.assertEqual(planned.call_count,1)
        self.assertEqual(planned.call_args.args[0]["request"]["gait_amplitude"],0.)
        self.assertEqual(row["request"]["command"],hold_motion_command(60,"clocked"))
        self.assertEqual(row["resolution_request"]["provider_request"]["command"],row["request"]["command"])
        self.assertFalse(row["output"]["actuation"]["safe_no_actuation"])

    def test_handoff_preserves_session_clock_memories_and_actual_history(self):
        host=self.prefix();session=host.session;composition=host.composition_memory
        before=copy.deepcopy(host.memory);history=copy.deepcopy(host.history);previous=list(host.previous)
        profile=host.force_policy.sha
        row=self.step(host,60);request=row["resolution_request"]["provider_request"]
        self.assertIs(host.session,session);self.assertIs(host.composition_memory,composition)
        self.assertEqual(row["request"]["memory"],before);self.assertEqual(request["history"],history)
        self.assertEqual([r["previous_applied_correction_rad_s"] for r in request["safety_envelope"]["ordered_actuator_limits"]],previous)
        self.assertEqual(host.force_policy.sha,profile)
        next_row=self.step(host,61)
        self.assertEqual(next_row["request"]["memory"],row["output"]["next_memory"])
        self.assertEqual(next_row["force_reference"]["decision"]["target_com"],row["force_reference"]["decision"]["target_com"])
        self.assertEqual(host.next_step,62)

    def test_all_retained_state_commands_keep_actual_residual_bounds(self):
        host=self.host()
        for i in range(120):
            previous=list(host.previous);row=self.step(host,i)
            self.assertIsNone(terminal_error(row))
            for j,command in enumerate(row["resolution"]["ordered_commands"]):
                self.assertLessEqual(abs(command["final_canonical_target_velocity_rad_s"]),3.5)
                self.assertLessEqual(abs(command["applied_correction_rad_s"]),3.5)
                if i>=HANDOFF:self.assertLessEqual(abs(command["applied_correction_rad_s"]-previous[j]),.08+1e-12)
            self.assertEqual(host.previous,[r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]])

    def test_out_of_order_post_handoff_state_closes_host(self):
        host=self.prefix()
        with self.assertRaises(ValueError):self.step(host,61)
        self.assertTrue(host.closed)

    def test_provider_failure_retains_fallback_and_closes_before_transfer(self):
        host=self.prefix()
        with patch.object(host.force_policy,"respond",side_effect=ValueError("injected failure")):row=self.step(host,60)
        self.assertTrue(host.closed);self.assertIsNotNone(terminal_error(row))
        self.assertTrue(row["resolution"]["deterministic_baseline_fallback_used"])
        self.assertTrue(all(r["applied_correction_rad_s"]==0. for r in row["resolution"]["ordered_commands"]))


if __name__=="__main__":unittest.main()
