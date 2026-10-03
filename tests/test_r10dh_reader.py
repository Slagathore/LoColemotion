"""New wire and identity boundary rejects crossed or incomplete evidence."""
import copy
import json
from pathlib import Path
import sys
import unittest
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10dh_reader as R
C,D=R.C,R.D


class Reader(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root=C.EVIDENCE/('r10dh-reader-controls-'+uuid.uuid4().hex);cls.root.mkdir()
        print('RETAINED_READER_CONTROLS '+cls.root.as_posix(),flush=True)

    def test_complete_wire_and_corruptions(self):
        for name in ('valid','digest','path','child','claim','reduced','duplicate','partial','missing'):
            folder=self.root/name;folder.mkdir();path=folder/'worker-streamed-report.json';D.write_new(path,dict(test_only=True))
            declaration=dict(attempt_id='parent',children=[dict(child_attempt_id='child')])
            receipt=dict(ok=True,**D.binding(path),parent_attempt_id='parent',child_attempt_id='child',
                transport_id='godot_4_7_sorted_full_precision_authoritative_json_v1',telemetry_reduced=False,
                physical_acceptance_authority=False,release_authority=False)
            if name=='digest':receipt['raw_sha256']='sha256:'+'0'*64
            if name=='path':receipt['path']=str(folder/'crossed')
            if name=='child':receipt['child_attempt_id']='crossed'
            if name=='claim':receipt['release_authority']=True
            if name=='reduced':receipt['telemetry_reduced']=True
            if name=='partial':Path(str(path)+'.partial').write_text('incomplete')
            line=R.FILE_MARKER+json.dumps(receipt)+'\n'
            (folder/'stdout.log').write_text('' if name=='missing' else line*(2 if name=='duplicate' else 1),encoding='utf-8')
            if name=='valid':self.assertEqual(path,R.retain_report(folder,declaration))
            else:
                with self.subTest(case=name),self.assertRaises(ValueError):R.retain_report(folder,declaration)

    def test_identity_and_prefix_refusals(self):
        folder=self.root/'header';child=folder/'children'/C.ROLES[0];child.mkdir(parents=True)
        cell=C.population('development_ghost')[0]
        context=dict(mode='development_ghost',cell_id=cell['cell_id'],role=cell['role'],seed=cell['seed'])
        declaration=dict(attempt_id='parent',children=[dict(child_attempt_id='child',role=cell['role'],evidence_path=child.as_posix())],
            r10dh_campaign=context,source_snapshot=dict(head='source'),seed=93671)
        D.write_new(folder/'declaration.json',declaration)
        report=dict(ok=True,parent_attempt_id='parent',child_attempt_id='child',arm_id=cell['role'],source_commit='source',seed=93671,
            seed_label=cell['seed']['label'],seed_sha256=cell['seed']['sha256'],held_out=False,held_out_cell_access_count=0,
            world_build_count=1,solver_step_count=1,global_solver_frame_count=1,r10dh_campaign=context,complete_route_proven=False,
            diagnostic_declaration_sha256=D.binding(folder/'declaration.json')['raw_sha256'],
            retained_arm=dict(walking_sessions=[dict(evaluation_segment_id='walking_prefix',start_receipt=dict(
                initial_gait_steps=dict.fromkeys(('front_left','front_right','rear_left','rear_right'),71)))]),
            terminal_same_body_identity_receipt=dict(ok=True),**dict.fromkeys(C.FLAGS,False))
        R.validate_report_header(report,declaration)
        for key,value in [('seed',93672),('held_out',True),('world_build_count',True),('solver_step_count',True),
                          ('child_attempt_id','crossed'),('official_qualification',True),('complete_route_proven',True)]:
            bad=copy.deepcopy(report);bad[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):R.validate_report_header(bad,declaration)
        bad=copy.deepcopy(report);bad['retained_arm']['walking_sessions'][0]['start_receipt']['initial_gait_steps']['front_left']=72
        with self.assertRaisesRegex(ValueError,'REPORT_PREFIX'):R.validate_report_header(bad,declaration)

    def test_raw_identity_bool_alias_refused(self):
        self.assertFalse(C.same(True,1));self.assertFalse(C.same(False,0))
        for mode in C.MODES:
            cells=C.population(mode);bad=copy.deepcopy(cells);bad[0]['seed']['seed']=True
            with self.assertRaises(ValueError):C.validate_population(bad,mode)


if __name__=='__main__':unittest.main(verbosity=2)
