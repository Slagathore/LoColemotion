"""Cold audit of compiler reuse controls; never compile or launch an engine."""
import json
from pathlib import Path

import development_recovery_candidate_build as build

ROOT = build.ROOT
PREFIX = 'sdk/development/recovery_candidates/'
NAMES = ('v11-compiler-cache-cold-v1', 'v11-compiler-cache-warm-v1')
RUNTIME_ROOT = build.entry.EVIDENCE / 'development-build-cache-runtime-a26196eeefae46baa37928461b8b91ac'


def fixtures(binding):
    path = Path(binding['compiled_fixtures']['path'])
    build.candidate.require(build.identity(path) == binding['compiled_fixtures'], 'CACHE_FIXTURE_DRIFT')
    return sorted([json.loads(line.partition(' ')[2]) for line in path.read_text().splitlines()
                   if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')],
                  key=lambda v: json.dumps(v, sort_keys=True))


def observe():
    bindings = []
    images = []
    for name in NAMES:
        path = ROOT / (PREFIX + name + '.runtime.json')
        binding = build.candidate.read(path)
        for artifact in binding['build_evidence_files']:
            build.candidate.require(build.identity(Path(artifact['path'])) == artifact, 'CACHE_BUILD_EVIDENCE_DRIFT')
        published = ROOT / binding['local_build_path']
        durable = Path(binding['runtime']['path'])
        build.candidate.require(build.identity(durable) == binding['runtime']
                                and build.candidate.sha(published) == binding['runtime']['raw_sha256'], 'CACHE_IMAGE_DRIFT')
        images.extend([published, durable])
        build.candidate.require(binding['core_test_count'] == 234
            and [s['stage'] for s in binding['build_stages']] == ['core_tests', 'fixtures', 'adapter']
            and all(s['exit_code'] == 0 for s in binding['build_stages']), 'CACHE_FRESH_TESTS')
        bindings.append(binding)
    cold, warm = bindings
    build.candidate.require(cold['source_files'] == warm['source_files'], 'CACHE_SOURCE_POPULATION')
    build.candidate.require(cold['compiler_cache']['key'] == warm['compiler_cache']['key']
        and cold['compiler_cache']['directory_existed_before_build'] is False
        and warm['compiler_cache']['directory_existed_before_build'] is True, 'CACHE_SEQUENCE')
    for i, first in enumerate(images):
        for second in images[i+1:]:
            build.candidate.require(not first.samefile(second), 'CACHE_RETAINED_IMAGE_ALIAS')
    build.candidate.require(cold['runtime']['raw_sha256'] == warm['runtime']['raw_sha256'], 'CACHE_IMAGE_BYTES')
    original = build.candidate.read(ROOT / (PREFIX + 'v11-matched-foot-reach-v1.runtime.json'))
    expected = fixtures(original)
    build.candidate.require(len(expected) == 6 and fixtures(cold) == expected and fixtures(warm) == expected,
                            'CACHE_OLD_CONTROLLER_FIXTURES_CHANGED')
    execution = json.loads((RUNTIME_ROOT / 'execution.json').read_text())
    build.candidate.require(execution['passed'] is True and execution['test_count'] == 4, 'CACHE_RUNTIME_CONTROLS')
    for stream in ('stdout', 'stderr'):
        build.candidate.require(build.candidate.sha(RUNTIME_ROOT / execution[stream]) == 'sha256:' + execution[stream+'_sha256'],
                                'CACHE_RUNTIME_LOG_DRIFT')
    return dict(schema_version='sporespore_development_recovery_build_cache_checkpoint_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='core_and_godot',
                          authority_mode='zero_world_compiler_reuse_controls', question_class='development'),
        bindings=[build.identity(ROOT / (PREFIX + name + '.runtime.json'), PREFIX + name + '.runtime.json') for name in NAMES],
        observed_build_stage_seconds=[dict(candidate_id=name,
            total=round(sum(s['elapsed_seconds'] for s in b['build_stages']), 6),
            stages=b['build_stages']) for name, b in zip(NAMES, bindings)],
        copied_dll_sha256=warm['runtime']['raw_sha256'], independent_retained_copy_count=len(images),
        cache_key=warm['compiler_cache']['key'], full_core_tests_each=234,
        original_controller_fixtures_preserved=6, runtime_controls=build.identity(RUNTIME_ROOT / 'execution.json'),
        original_v11_dll_unchanged=build.identity(Path(original['runtime']['path'])) == original['runtime'],
        limitation='One cold/warm unchanged-Rust-source build pair. Times cover three build stages, not controller design, helper overhead, changed-source compilation, safety gates, or physical runs. Cargo still checks dependencies and all tests run anew.',
        world_build_count=0, solver_step_count=0, qualification_evidence_reused=False,
        physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(observe(), indent=2, allow_nan=False))
