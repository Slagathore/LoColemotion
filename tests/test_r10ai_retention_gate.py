"""One fresh production-retention test covers all eleven retained PS controls."""
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10ai_retention_check as check


class RetentionGate(unittest.TestCase):
    def test_retention_and_native_selection_controls(self):
        # The inner helper retains its original streams, metadata and source snapshots.
        result=subprocess.run([sys.executable,'-B',str(Path(check.__file__))],cwd=check.ROOT,
            stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=150,creationflags=subprocess.CREATE_NO_WINDOW)
        sys.stdout.write(result.stdout.decode('utf-8'));sys.stderr.write(result.stderr.decode('utf-8'))
        self.assertEqual(result.returncode,0)
        roots=[Path(x.split(' ',1)[1]) for x in result.stdout.decode('utf-8').splitlines() if x.startswith('R10AI_RETENTION_CHECK ')]
        self.assertEqual(len(roots),1)
        root=roots[0];self.assertEqual(root.parent,check.EVIDENCE)
        value=json.loads((root/'result.json').read_text(encoding='utf-8-sig'))
        self.assertTrue(value['ok']);self.assertEqual(len(value['cases']),11)
        self.assertTrue(all(x['passed'] for x in value['cases']))
        self.assertEqual(value['world_build_count'],0);self.assertEqual(value['solver_step_count'],0)
        self.assertFalse(value['physical_acceptance_authority']);self.assertFalse(value['release_authority'])
        self.assertEqual(check.base.read(root/'source_before.json'),check.base.read(root/'source_after.json'))


if __name__=='__main__':unittest.main()
