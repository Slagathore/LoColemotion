"""Exact v7 diagnostic host images. File checks confer no world authority."""
import argparse
import json
from pathlib import Path
import sys

import qsdk_r10f_l14_runtime_binding as predecessor
import r10aj_development as identity

SCHEMA = 'sporespore_r10aj_diagnostic_runtime_image_binding_v1'
CONTRACT = identity.ROOT / 'sdk/development/r10aj_host_runtime_contract_v1.json'
CONTRACT_SHA = 'sha256:4da10c75087f4efc1958c220b23de2703bebaf02b03aac201fa9101bf4f22e93'


def expected_binding():
    identity.require(identity.sha(CONTRACT) == CONTRACT_SHA, 'HOST_CONTRACT_DRIFT')
    return json.loads(CONTRACT.read_text(encoding='utf-8'))


def validate_binding(value):
    identity.require(predecessor.authority.design_audit.exact(value, expected_binding()), 'HOST_BINDING_NOT_EXACT')


def bind_runtime(godot, powershell_executable):
    predecessor.authority.verify_repository()
    value = expected_binding()
    for role, offered in [('godot_console', godot), ('python_helper', sys.executable),
                          ('powershell_host', powershell_executable)]:
        identity.require(Path(offered).resolve() == Path(value['images'][role]['path']).resolve(),
                         'HOST_SELECTED_PATH:' + role)
    for role, expected in value['images'].items():
        identity.require(predecessor.authority.design_audit.exact(
            predecessor.file_identity(Path(expected['path'])), expected), 'HOST_IMAGE:' + role)
    for field in ('diagnostic_design', 'observer_component', 'classification_component'):
        expected = value[field]
        identity.require(predecessor.file_identity(identity.ROOT / expected['path'],
            display_path=expected['path']) == expected, 'HOST_DEPENDENCY:' + field)
    return value


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--powershell-host', required=True)
    args = parser.parse_args()
    print(json.dumps(bind_runtime(args.godot, args.powershell_host), separators=(',', ':')))
