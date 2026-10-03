"""Resolve the inherited task seed through an explicit pre-world correction.

The finite-task evaluator remains immutable. Population authority is the R10AG
design; this record exposes the stale metadata instead of silently changing it.
"""
import json
from pathlib import Path
import r10ag_development as identity

RECORD = identity.ROOT / 'sdk/recovery/r10ag_population_binding_correction_v1.json'


def reference():
    return dict(path=RECORD.relative_to(identity.ROOT).as_posix(), raw_sha256=identity.sha(RECORD))


def audit(value=None):
    value = json.loads(RECORD.read_bytes()) if value is None else value
    def require(ok):
        if not ok:
            raise ValueError('R10AG_POPULATION_BINDING_CORRECTION')
    require(value['schema_version'] == 'sporespore_r10ag_population_binding_correction_v1')
    sources = {}
    for key in ('finite_task', 'design'):
        path = identity.ROOT / value[key]['path']
        require(path.resolve().is_relative_to(identity.ROOT.resolve()))
        require(identity.sha(path) == value[key]['raw_sha256'])
        sources[key] = json.loads(path.read_bytes())
    require(value['design']['raw_sha256'] == identity.DESIGN_SHA)
    require(value['superseded_field'] == 'prospective_populations.development.first_probe.seed')
    require(value['superseded_value'] == 51008 == sources['finite_task']['prospective_populations']['development']['first_probe']['seed'])
    require(value['authoritative_field'] == 'first_probe')
    require(value['population'] == sources['design']['first_probe'])
    population = value['population']
    require(type(population['seed']) is int and population['seed'] == identity.SEED)
    require(population['prefix_phase'] == identity.PHASE and population['roles'] == [identity.ROLE])
    require(population['execution_mode'] == identity.SINGLE and population['attempt_limit'] == 1)
    require(all(value[key] is False for key in ('physical_execution_authorized', 'physical_acceptance_authority', 'release_authority')))
    return dict(ok=True, seed=population['seed'], prefix_phase=population['prefix_phase'],
        roles=population['roles'], binding=reference(), inherited_seed_is_not_authorized=True,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(audit()))
