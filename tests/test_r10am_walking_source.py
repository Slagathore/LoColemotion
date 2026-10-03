"""Explicit detection-frame source admission and real walking adapter transport."""
import json
from types import SimpleNamespace
import unittest
import uuid
import test_r10am_contact_report as shared

class R10AMWalkingSource(unittest.TestCase):
    def test_production_source_preparation_adapter_and_refusals(self):
        out=shared.identity.EVIDENCE/('r10am-walking-source-'+uuid.uuid4().hex);out.mkdir()
        print('R10AF_WALKING_SOURCE_ROOT '+str(out),flush=True)
        before=shared.entry._source_snapshot()
        (out/'source-before.json').write_text(json.dumps(before),encoding='utf-8')
        result=shared.native_helper.R10AECompleteReport.native(SimpleNamespace(out=out),'native',
            'res://tests/test_r10am_walking_source.gd',[out/'fixtures.json'],timeout=90)
        after=shared.entry._source_snapshot()
        (out/'source-after.json').write_text(json.dumps(after),encoding='utf-8')
        self.assertEqual(before,after)
        self.assertEqual(0,result.returncode,result.stdout[-5000:].decode()+result.stderr.decode())
        self.assertEqual(b'',result.stderr)
        fixed=json.loads((out/'fixtures.json').read_text(encoding='utf-8'))
        self.assertIs(fixed['ok'],True);self.assertTrue(all(fixed['checks'].values()))
        self.assertEqual(7,fixed['negative_controls']);self.assertEqual(6,len(fixed['cases']))
        self.assertEqual((0,0),(fixed['world_build_count'],fixed['solver_step_count']))

if __name__=='__main__':unittest.main()
