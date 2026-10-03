"""Audit the built contact-frame observer and its zero-world checks.

Native contact population and production host integration remain unproven.
No physics is launched by this auditor and no consumed result is reinterpreted.
"""
import argparse
import json
from pathlib import Path

import r10ac_contact_frame_patch as patch
from r10ac_support_loss_diagnosis import ROOT, EVIDENCE, binding, write

RUN = EVIDENCE / 'r10ac-contact-frame-build-ac6fc57f978740a8926c9955f4b572b1'
BUILD = RUN / 'build-02'
CHECK = RUN / 'check-01'
RECORD = ROOT / 'sdk/recovery/r10ac_contact_frame_component_v1.json'
DESIGN = ROOT / 'sdk/recovery/r10ac_contact_frame_observer_design_v2.json'
TESTS = (
    ('test_r10ac_contact_frames_zero_world', 'R10AC_CONTACT_FRAMES_ZERO_WORLD '),
    ('test_sdk_qsdk_r24d157_godot_jolt_rotation_integration_energy_zero_world',
     'QSDK_R24D157_GODOT_JOLT_ROTATION_INTEGRATION_ENERGY_ZERO_WORLD '),
)
read = lambda path: json.loads(Path(path).read_text(encoding='utf-8-sig'))


def result_line(path, marker):
    matches = [line[len(marker):] for line in path.read_text(encoding='utf-8-sig').splitlines()
               if line.startswith(marker)]
    assert len(matches) == 1
    return json.loads(matches[0])


def observations():
    design = read(DESIGN)
    assert patch.PATCH.read_text(encoding='utf-8') == patch.render()
    native_source = patch.verify_checkout(design['engine_source']['checkout'])
    assert native_source == design['engine_source'] == read(BUILD/'source-before.json') == read(BUILD/'source-after.json')
    assert read(BUILD/'command.json')['arguments'] == design['build']['command'][1:]
    for row in read(BUILD/'repository-inputs.json'):
        current = binding(ROOT/row['path'])
        assert current['raw_sha256'] == 'sha256:'+row['sha256'].lower()
        assert current['byte_length'] == row['bytes']
    built = read(BUILD/'result.json')
    assert built['ok'] is True and built['build_exit_code'] == 0
    assert built['world_build_count'] == built['solver_step_count'] == 0
    # These build-only warnings are retained verbatim. Runtime test stderr must
    # still be empty; successful compilation does not waive native test errors.
    expected_warnings = (
        'WARNING: The ANGLE rendering driver requires dependencies to be installed.\n'
        'You can install them by running `python misc\\scripts\\install_angle.py`.\n'
        'See the documentation for more information:\n'
        '\thttps://docs.godotengine.org/en/latest/engine_details/development/compiling/compiling_for_windows.html\n'
        'Alternatively, disable this driver by compiling with `angle=no` explicitly.\n'
        + 'WARNING: msgfmt not found, using .po files instead of .mo\n' * 4
    )
    assert (BUILD/'build.stderr.log').read_text(encoding='utf-8-sig') == expected_warnings
    assert 'scons: done building targets.' in (BUILD/'build.stdout.log').read_text(encoding='utf-8-sig')
    for item in built['artifacts']:
        current = binding(item['path'])
        assert current['raw_sha256'] == 'sha256:'+item['sha256'].lower()
        assert current['byte_length'] == item['bytes']
    tested = []
    for name, marker in TESTS:
        receipt = read(CHECK/(name+'.execution.json'))
        assert receipt['exit_code'] == receipt['stderr_bytes'] == 0
        assert (CHECK/(name+'.stderr.log')).read_bytes() == b''
        command = read(CHECK/(name+'.command.json'))
        assert Path(command['executable']) == BUILD/'godot.windows.editor.dev.x86_64.console.exe'
        assert command['arguments'] == ['--headless','--path',str(ROOT).replace('\\','/'),'--script','res://tests/'+name+'.gd']
        result = result_line(CHECK/(name+'.stdout.log'), marker)
        assert result['ok'] is True
        assert result['world_build_count'] == result['solver_step_count'] == 0
        assert result['native_field_population_observed'] is False
        assert result['physical_acceptance_authority'] is result['release_authority'] is False
        tested.append(result)
    new, previous = tested
    assert new['native_invalid_rid_refusals'] == 3
    assert new['synthetic_positive_cases'] == 2 and new['synthetic_negative_cases'] == 39
    assert new['detached_snapshot_checked'] is True
    assert previous['invalid_rid_refusal_observed'] is True
    assert previous['consumer_check_count'] == 38 and previous['consumer_mutation_rejection_count'] == 17
    failed = read(RUN/'build-01/result.json')
    assert failed['ok'] is False and failed['build_exit_code'] == 255
    errors = (RUN/'build-01/build.stderr.log').read_text(encoding='utf-8-sig')
    assert 'accesskit=no' in errors and 'd3d12=no' in errors
    original = read(RUN/'build-01/repository-inputs.json')
    expected = next(row for row in original if row['path'] == 'sdk/build_r10ac_contact_frames.ps1')
    assert binding(RUN/'build-01/build-runner-source.ps1')['raw_sha256'] == 'sha256:'+expected['sha256'].lower()
    assert 'Cannot infer the type of "transform_key"' in (RUN/'parse.stderr.log').read_text(encoding='utf-8-sig')
    assert read(RUN/'parse2.execution.json')['stderr_bytes'] == 0
    assert (RUN/'parse2.stderr.log').read_bytes() == b''
    assert read(CHECK/'lock.json')['acquired'] is True and read(BUILD/'lock.json')['acquired'] is True
    return dict(ok=True, engine=binding(BUILD/'godot.windows.editor.dev.x86_64.exe'),
        native_invalid_rid_refusals=3, synthetic_positive_cases=2, synthetic_negative_cases=39,
        previous_energy_consumer_checks=38, previous_energy_mutation_refusals=17,
        previous_energy_invalid_rid_refusal=True, exact_source_unchanged_during_build=True,
        failed_build_and_parser_attempts_retained=True, frozen_v6_checkout_preserved=True,
        retained_build_warnings=['ANGLE dependency unavailable', 'msgfmt .po fallback (four messages)'],
        native_field_population_observed=False, production_host_capture_integrated=False,
        controller_changed=False, foot_classifier_changed=False, physical_population_declared=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def capture():
    result = observations()
    sources = [Path(__file__), DESIGN, patch.PATCH, Path(patch.__file__),
        ROOT/'sdk/recovery/r10ac_contact_frame_observer_design_v1.json',
        ROOT/'sdk/recovery/r10ac_contact_sampling_component_v1.json',
        ROOT/'sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd',
        ROOT/'sdk/adapters/godot/gdscript/recovery_solver_energy_exchange_v2.gd',
        ROOT/'sdk/build_r10ac_contact_frames.ps1',
        ROOT/'sdk/conformance/r10ac_contact_sampling_component.py',
        ROOT/'sdk/conformance/r10ac_support_loss_diagnosis.py']
    sources += [ROOT/('tests/'+name+'.gd') for name, _ in TESTS]
    # Only these bounded attempt directories, never a repository-wide traversal.
    files = [p for folder in (RUN, RUN/'build-01', BUILD, CHECK)
             for p in sorted(folder.iterdir()) if p.is_file()]
    write(RECORD, dict(schema_version='sporespore_r10ac_contact_frame_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='built_native_observer_and_zero_world_consumer_checks', question_class='development'),
        source_bindings=[binding(p) for p in sources], retained_evidence=[binding(p) for p in files],
        observed=result,
        claim_limit='Registration, invalid-RID refusal and synthetic admission only. No native contact fields were populated in physics, no route safety gate or acceptance campaign is qualified, and no consumed recovery result is regraded.',
        next_action='Integrate the opt-in observer into a distinct production-path development capture. Retain all nine exact callback transforms and their direct-state source, bind contact step and body/shape identities, independently replay comparisons, then qualify the complete applicable safety gate before a fresh bounded physical diagnostic.'))
    return result


def audit():
    record = read(RECORD)
    for row in record['source_bindings'] + record['retained_evidence']:
        assert binding(row['path']) == row
    result = observations()
    assert record['observed'] == result
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    print('R10AC_CONTACT_FRAME_COMPONENT '+json.dumps(capture() if parser.parse_args().capture else audit()), flush=True)
