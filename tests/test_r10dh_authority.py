"""Adversarial finite authority graph checks using a world-free in-memory graph."""
import copy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'sdk/conformance'))
import r10dh_authority as A
C, M = A.C, A.M


def graph():
    f,q,h = ('1'*40,'2'*40,'3'*40); key='sha256:'+'4'*64
    manifest=dict(production_route_key=key)
    prereg=dict(cells=C.population('held_out'),all_cells_must_pass=True,retry_permitted=False,
                baseline_reuse_permitted=False,physical_execution_authorized=False)
    ghost=dict(production_route_key=key,declared_cells=C.population('development_ghost'),
        branch_coverage=dict(no_kick=True,canonical_prone=True,fresh_walking=True,settled_stop=True),
        held_out_worlds_opened=0,physical_acceptance_authority=False)
    ghost.update(dict.fromkeys(('production_route_ghost_passed','all_tasks_positive','original_host_success',
        'original_publication_complete','owned_cleanup_complete','source_unchanged','independent_audit_ok'),True))
    encode=lambda v:json.dumps(v,sort_keys=True).encode()
    qual=dict(passed=True,source_freeze_commit=f,world_build_count=0,solver_step_count=0,physical_execution_authorized=False,
        production_route_key=key,manifest_sha256=C.sha(encode(manifest)),preregistration_sha256=C.sha(encode(prereg)))
    auth=dict(schema_version='sporespore_r10dh_execution_authority_v1',campaign_id='R10DH-HELD-OUT-FINITE-DECISION-V1',
        cells=C.population('held_out'),source_freeze_commit=f,qualification_commit=q,
        maximum_campaign_attempts=1,maximum_world_attempts=6,maximum_solver_steps=18912,all_cells_must_pass=True,
        all_cells_run_regardless_of_behavior=True,retry_permitted=False,cell_replacement_permitted=False,
        baseline_reuse_permitted=False,threshold_override_permitted=False,physical_execution_authorized=True,
        physical_acceptance_authority=False,release_authority=False,qualification_sha256=C.sha(encode(qual)),
        ghost_sha256=C.sha(encode(ghost)),manifest_sha256=C.sha(encode(manifest)),preregistration_sha256=C.sha(encode(prereg)))
    blobs={(h,M.AUTHORITY):encode(auth),(q,M.QUALIFICATION):encode(qual),(f,M.GHOST):encode(ghost),
           (f,M.MANIFEST):encode(manifest),(f,M.PREREGISTRATION):encode(prereg)}
    return auth,qual,ghost,dict(head=h,parents=lambda c:{h:[q],q:[f]}[c],
        changes=lambda c:{h:[M.AUTHORITY],q:[M.QUALIFICATION]}[c],blob=lambda c,p:blobs[c,p])


class Authority(unittest.TestCase):
    def test_exact_graph(self):
        a,q,g,args=graph();self.assertEqual('1'*40,A.validate_graph(a,q,g,**args)['source_freeze_commit'])

    def test_extra_commit_or_source_change_refused(self):
        for override in (dict(parents=lambda c:['0'*40]),dict(changes=lambda c:[M.AUTHORITY,'sdk/changed.py'])):
            a,q,g,args=graph();args.update(override)
            with self.assertRaises(ValueError):A.validate_graph(a,q,g,**args)

    def test_population_and_authority_escalation_refused(self):
        for key,value in [('cells',C.population('held_out')[:-1]),('retry_permitted',True),('maximum_world_attempts',True),
                          ('physical_acceptance_authority',True),('release_authority',True),('all_cells_must_pass',False)]:
            a,q,g,args=graph();a[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):A.validate_graph(a,q,g,**args)

    def test_ghost_workflow_failures_refused(self):
        for key in ('original_host_success','owned_cleanup_complete','source_unchanged','all_tasks_positive','independent_audit_ok'):
            a,q,g,args=graph();g[key]=False
            # Bind the changed fixture to prove a committed negative cannot qualify.
            old=args['blob'];raw=json.dumps(g,sort_keys=True).encode();a['ghost_sha256']=C.sha(raw)
            ar=json.dumps(a,sort_keys=True).encode()
            args['blob']=lambda c,p,old=old,raw=raw,ar=ar:raw if p==M.GHOST else ar if p==M.AUTHORITY else old(c,p)
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'GHOST_INCOMPLETE'):A.validate_graph(a,q,g,**args)

    def test_raw_record_drift_refused(self):
        a,q,g,args=graph();old=args['blob']
        args['blob']=lambda c,p:old(c,p)+b' ' if p==M.QUALIFICATION else old(c,p)
        with self.assertRaisesRegex(ValueError,'GRAPH_BINDING'):A.validate_graph(a,q,g,**args)


if __name__=='__main__':unittest.main(verbosity=2)
