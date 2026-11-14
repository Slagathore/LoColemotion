"""Refusal controls for pure validator selection and native execution receipts."""
import copy
import hashlib
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
import uuid

from materialize_native_source_validation import materialize,requested,validate_summary

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
COLLECTION='sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd'


class NativeValidationControls(unittest.TestCase):
    def fixture(self):
        project=Path(os.environ['EXPLORER_TEST_OUTPUT'])/('native-validation-control-'+uuid.uuid4().hex)
        worker=project/'sdk/explorer/native_recovery/worker.gd';collection=project/COLLECTION
        worker.parent.mkdir(parents=True);collection.parent.mkdir(parents=True)
        (project/'sdk/explorer/studio').mkdir()
        worker.write_bytes((HERE/'godot_live_walking_worker.gd').read_bytes())
        collection.write_bytes((ROOT/COLLECTION).read_bytes())
        library=project/'fixture.dll';library.write_bytes(b'not executable; materialization control only\n')
        return project,worker,collection,library,hashlib.sha256(library.read_bytes()).hexdigest()

    def test_request_refuses_unpaired_images_and_other_routes(self):
        args=SimpleNamespace(live_walking=True,walking_steps=119,native_validator='image',native_validator_sha256='a'*64,source_validation_policy='native')
        self.assertEqual(requested(args)['policy'],'native')
        for key,value in [('native_validator',None),('native_validator_sha256',None),('source_validation_policy','unknown'),
                ('live_walking',False),('walking_steps',1800),('serializer_cache_policy','lru')]+[(k,True) for k in
                ('bridge_profile','startup_packets','probe_impulses','epoch_boundary_probe','energy_epoch_probe','live_handoff')]:
            with self.subTest(key=key),self.assertRaises(ValueError):requested(SimpleNamespace(**(vars(args)|{key:value})))
        with self.assertRaises(ValueError):requested(SimpleNamespace(source_validation_policy='native'))
        self.assertIsNone(requested(SimpleNamespace()))

    def test_materialization_preserves_original_predicate(self):
        for policy in ('original','native'):
            project,worker,collection,library,digest=self.fixture();original=collection.read_text()
            self.assertEqual(materialize(project,library,digest,policy)['policy'],policy)
            prefix=collection.read_text().split('\nstatic var studio_original_validation_calls:')[0]
            self.assertEqual(prefix.replace('_studio_reference_json_source_v1(','_json_source_v1(').rstrip(),original.rstrip())
            self.assertEqual(worker.read_text().count('super._verify_l15_prepared_context_before_world_v1()'),1)
            with self.assertRaises(ValueError):materialize(project,library,digest,policy)

    def test_materialization_refuses_drift_and_wrong_image(self):
        for problem in ('signature','duplicate','image','policy'):
            project,worker,collection,library,digest=self.fixture()
            if problem=='signature':worker.write_text(worker.read_text().replace('func _verify_l15_prepared_context_before_world_v1()', 'func changed()'))
            if problem=='duplicate':worker.write_text(worker.read_text()+'\nfunc _verify_l15_prepared_context_before_world_v1() -> bool:\n\treturn false\n')
            before=worker.read_bytes(),collection.read_bytes()
            with self.subTest(problem=problem),self.assertRaises((ValueError,AssertionError)):
                materialize(project,library,'0'*64 if problem=='image' else digest,'unknown' if problem=='policy' else 'native')
            self.assertEqual((worker.read_bytes(),collection.read_bytes()),before)

    def summary(self,policy):
        return dict(ok=True,policy=policy,preworld_verified=True,version='sporespore_finite_source_validation_v1',
            oracle_controls=dict(ok=True,checks=2424,failures=[],world_build_count=0,solver_steps=0),
            dispatch_controls=dict(ok=True,checks=4),original_calls=12 if policy=='original' else 0,
            compiled_calls=12 if policy=='native' else 0,additional_controller_calls=0,additional_physics_reads=0,
            additional_solver_steps=0,physical_acceptance_authority=False,release_authority=False)

    def test_reader_refuses_mixed_backend_missing_execution_and_overclaims(self):
        for policy in ('original','native'):
            source=self.summary(policy);self.assertTrue(validate_summary(source,policy,True)['ok'])
            mutations=[lambda s:s.update(policy='crossed'),lambda s:s.update(preworld_verified=False),
                lambda s:s.update(version='stale'),lambda s:s.update(original_calls=True),
                lambda s:s.update(original_calls=-1),lambda s:s.update(original_calls=1,compiled_calls=1),
                lambda s:s.update(original_calls=0,compiled_calls=0),lambda s:s.update(additional_solver_steps=1),
                lambda s:s.update(additional_controller_calls=True),lambda s:s.update(physical_acceptance_authority=True),
                lambda s:s.update(release_authority=0),lambda s:s['oracle_controls'].update(checks=2423),
                lambda s:s['oracle_controls'].update(world_build_count=False),lambda s:s['oracle_controls'].update(failures=['failure']),
                lambda s:s['dispatch_controls'].update(checks=3)]
            for index,mutate in enumerate(mutations):
                value=copy.deepcopy(source);mutate(value)
                with self.subTest(policy=policy,index=index),self.assertRaises(ValueError):validate_summary(value,policy,True)


if __name__=='__main__':unittest.main()
