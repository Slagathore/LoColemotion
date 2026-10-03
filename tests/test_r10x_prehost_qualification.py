"""Prehost evidence and acyclic F/Q/A reuse controls without physical work."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10x_prehost_qualification as q


def snapshot(head):
    return dict(head=head,remote=q.authority.REMOTE,status='',changed_files=[])


class Prehost(unittest.TestCase):
    def test_original_timing_provenance_cannot_be_renamed(self):
        value=q.files.read(q.CONTRACT);q.validate_timing_provenance(value)
        value['startup_timing_evidence']['diagnostic_manifest']['path']='nonexistent-renamed-evidence.json'
        with self.assertRaisesRegex(ValueError,'TIMING_PROVENANCE'):q.validate_timing_provenance(value)

    def test_stale_dependencies_and_source_refuse(self):
        root=q.EVIDENCE/('r10x-prehost-'+uuid.uuid4().hex);root.mkdir()
        path=root/'qualification.json'
        value=dict(schema_version='sporespore_r10x_prehost_qualification_v1',ok=True,dependencies={'synthetic':'old'},source_snapshot={},**q.CLAIMS)
        q.files.write_new(path,value)
        with patch.object(q,'dependencies',return_value={'synthetic':'changed'}):
            with self.assertRaisesRegex(ValueError,'DEPENDENCIES_CHANGED'):q.verify(path)
        with patch.object(q,'dependencies',return_value=value['dependencies']):
            with self.assertRaisesRegex(ValueError,'SOURCE_CHANGED'):q.verify(path)

    def test_owned_cleanup_requires_matching_creation_identity(self):
        root=q.EVIDENCE/('r10x-prehost-controls-'+uuid.uuid4().hex);root.mkdir()
        # Nested fixture must not impersonate a real launched host request.
        host=root/('r10x-production-host-'+uuid.uuid4().hex);host.mkdir()
        request=host/'request.json';q.files.write_new(request,dict(synthetic_zero_world_fixture=True))
        (root/'owned_requests.jsonl').write_text(json.dumps(q.files.bind(request))+'\n',encoding='utf-8')
        identity=q.win.current_identity();q.files.write_new(host/'host_started.json',dict(host_identity=identity))
        with patch.object(q,'EVIDENCE',root):
            self.assertFalse(q.owned_quiescent(root))
            crossed=dict(identity,creation_filetime=identity['creation_filetime']+1)
            (host/'host_started.json').write_text(json.dumps(dict(host_identity=crossed)),encoding='utf-8')
            self.assertTrue(q.owned_quiescent(root))
        with self.assertRaisesRegex(ValueError,'OWNED_REQUEST_PATH'):q.owned_quiescent(root)

    def test_same_owned_snapshot_or_exact_clean_commit_chain(self):
        f,qq,a='1'*40,'2'*40,'3'*40
        original=snapshot(f)
        self.assertTrue(q.source_compatible(original,copy.deepcopy(original)))
        def git(*args):
            if args[0]=='rev-list':return qq+'\n'+a
            if args[0]=='show':return f if args[-1]==qq else qq
            if args[0]=='diff-tree':return q.authority.QUALIFICATION_PATH if args[-1]==qq else q.authority.AUTHORITY_PATH
            self.fail(args)
        with patch.object(q.authority,'git',side_effect=git):self.assertTrue(q.source_compatible(original,snapshot(a)))

    def test_unrelated_source_commit_merge_or_extra_path_cannot_reuse(self):
        f,a='1'*40,'3'*40
        for replies in [[a,'4'*40], [a,f+' '+'2'*40], [a,f,'sdk/conformance/changed.py'], ['\n'.join(['2'*40,a,'4'*40])]]:
            with self.subTest(replies=replies),patch.object(q.authority,'git',side_effect=replies):
                self.assertFalse(q.source_compatible(snapshot(f),snapshot(a)))

    def test_dirty_crossed_source_and_untyped_claims_refuse(self):
        for current in [dict(snapshot('2'*40),status=' M sdk/x.py'),dict(snapshot('2'*40),changed_files=[{}]),dict(snapshot('2'*40),remote='other')]:
            with self.subTest(current=current):self.assertFalse(q.source_compatible(snapshot('1'*40),current))
        root=q.EVIDENCE/('r10x-prehost-'+uuid.uuid4().hex);root.mkdir()
        value=dict(schema_version='sporespore_r10x_prehost_qualification_v1',ok=True,**q.CLAIMS)
        value['world_build_count']=False;q.files.write_new(root/'qualification.json',value)
        with self.assertRaisesRegex(ValueError,'CLAIMS'):q.verify(root/'qualification.json')


if __name__=='__main__':unittest.main()
