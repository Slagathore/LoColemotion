"""Declare a fresh R10AB interface source key; never refresh consumed keys.

The key admits a candidate for checking. Complete safety qualification and
single-use launch reservation remain separate requirements.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
BASE = ROOT / 'sdk/recovery/r10aa_v56_walking_entry_contract_v8.json'
SELECTORS = [ROOT / 'sdk/conformance/development_recovery_candidate.py',
    ROOT / 'sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd']


def sha(path):
    return 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def declare(reason):
    assert Path(git('rev-parse', '--show-toplevel')).resolve() == ROOT
    assert git('remote', 'get-url', 'origin') == 'https://github.com/Slagathore/sporespore.git'
    assert reason.strip()
    assert not list(EVIDENCE.glob('r10ab*consumption*.json')), 'R10AB population consumed'
    # A retained R10AB physical declaration also closes this helper even if its
    # launch later failed. Source successors after exposure need a new design.
    for path in EVIDENCE.glob('development-recovery-smoke-*/declaration.json'):
        if 'r10ab_development' in json.loads(path.read_text(encoding='utf-8-sig')):
            raise ValueError('R10AB physical population declared')
    versions = list((ROOT / 'sdk/recovery').glob('r10ab_v56_walking_entry_contract_v*.json'))
    revision = 1 + max([int(re.search(r'_v(\d+)\.json$', p.name)[1]) for p in versions], default=0)
    previous = max(versions, key=lambda p: int(re.search(r'_v(\d+)\.json$', p.name)[1])) if versions else BASE
    target = ROOT / 'sdk/recovery' / f'r10ab_v56_walking_entry_contract_v{revision}.json'
    assert not target.exists()
    for path in SELECTORS:
        text, count = re.subn(r'r10ab_v56_walking_entry_contract_v\d+\.json', target.name, path.read_text(encoding='utf-8'))
        assert count == 1
        path.write_text(text, encoding='utf-8', newline='\n')
    value = json.loads(BASE.read_text(encoding='utf-8'))
    paths = {item['path'] for item in value['bound_source_files']}
    paths.add(BASE.relative_to(ROOT).as_posix())
    paths.add(previous.relative_to(ROOT).as_posix())
    paths.update(path for path in git('ls-files', '--cached', '--others', '--exclude-standard').splitlines()
        if 'r10ab' in path and Path(path).suffix in ('.py', '.gd', '.rs', '.h', '.ps1', '.json', '.gdextension')
        and not re.search(r'r10ab_v56_walking_entry_contract_v\d+\.json$', path))
    paths.update(['sdk/conformance/development_passive_entry_profile.py', 'sdk/conformance/development_recovery_smoke.py',
        'sdk/run_development_interfaces.ps1', 'sdk/run_development_recovery_smoke.ps1'])
    value.update(schema_version=f'sporespore_r10ab_v56_walking_entry_contract_v{revision}',
        profile_id='r10ab_v56_joint_bounded_contact_gated_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='prospective_development_source_binding', question_class='development'),
        required_start_profile_id='r10ab_v56_front_left_first_post_interaction_v1',
        required_walking_policy_id='r10ab_partial_downward_rise_route_v1',
        rationale='Bind the distinct V24 phase-aware downward-rise partial controller composition to unchanged walking, readiness and hold laws.',
        compatibility_scope='R10AB development only; no previous key, result or qualification is refreshed.',
        diagnostic_basis=dict(native_component='sdk/recovery/r10ab_partial_native_component_v1.json',
            native_component_sha256=sha(ROOT / 'sdk/recovery/r10ab_partial_native_component_v1.json'),
            physical_outcome_predicted=False, causal_attribution_proven=False),
        source_key_complete=True, predecessor_contract=previous.relative_to(ROOT).as_posix(),
        predecessor_contract_sha256=sha(previous), source_revision_reason=reason,
        dependency_coverage='Conservative consumed R10AA input population at current bytes plus every R10AB source, contract, test and binding. '
            'The key is candidate admission only; complete affected-path safety qualification and launch reservation are separate.',
        bound_source_files=[dict(path=path, byte_length=(ROOT / path).stat().st_size, raw_sha256=sha(ROOT / path)) for path in sorted(paths)])
    with target.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')
    return dict(path=target.relative_to(ROOT).as_posix(), raw_sha256=sha(target), source_files=len(paths),
        physical_execution_authorized=False, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reason', required=True)
    print(json.dumps(declare(parser.parse_args().reason)))
