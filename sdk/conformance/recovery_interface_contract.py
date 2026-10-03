"""One data contract for future recovery interfaces; no physics or old-record edits.

Python reads the source directly. Rust's build script reads the same source.
The two checked-in script projections are verified by the development gate.
Use --write only to regenerate those two declared files after a contract edit.
"""
import argparse
import json
from pathlib import Path
import re

SDK = Path(__file__).resolve().parents[1]
CONTRACT_PATH = SDK / 'core/contracts/recovery_interfaces_v1.json'
GDSCRIPT_PATH = SDK / 'adapters/godot/gdscript/recovery_interface_contract_v1.gd'
POWERSHELL_PATH = SDK / 'process/recovery_interface_contract_v1.ps1'


def load_contract():
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError('RECOVERY_INTERFACE_DUPLICATE_KEY:' + key)
            result[key] = value
        return result
    value = json.loads(CONTRACT_PATH.read_text(encoding='utf-8'), object_pairs_hook=pairs)
    validate_contract(value)
    return value


def validate_contract(value):
    def require(condition):
        if not condition:
            raise ValueError('RECOVERY_INTERFACE_CONTRACT_INVALID')
    require(type(value) is dict and set(value) == {
        'schema_version', 'canonical_owners', 'no_actuation_mapping', 'recovery_controller_id', 'process'})
    require(value['schema_version'] == 'sporespore_recovery_interfaces_v1')
    owners = value['canonical_owners']
    require(type(owners) is list and len(owners) > 0)
    variants, wires = set(), set()
    for owner in owners:
        require(type(owner) is dict and set(owner) == {'rust_variant', 'wire_name'})
        variant, wire = owner['rust_variant'], owner['wire_name']
        require(type(variant) is str and re.fullmatch('[A-Z][A-Za-z0-9]*', variant) is not None)
        require(type(wire) is str and re.fullmatch('[a-z][a-z0-9_]*', wire) is not None)
        require(variant not in variants and wire not in wires)
        variants.add(variant)
        wires.add(wire)
    mapping = value['no_actuation_mapping']
    require(type(mapping) is dict and bool(mapping))
    require(all(type(key) is str and re.fullmatch('[a-z][a-z0-9_]*', key) is not None
                and type(item) is str and item in wires for key, item in mapping.items()))
    require(type(value['recovery_controller_id']) is str and
            re.fullmatch('[a-z][a-z0-9_]*', value['recovery_controller_id']) is not None)
    process = value['process']
    require(type(process) is dict and set(process) == {'context_schema', 'receipt_schema', 'ready_schema',
        'termination_protocol_id', 'ready_marker_prefix', 'roles', 'self_relationship',
        'descendant_relationship', 'maximum_chain_nodes'})
    for key in ('context_schema', 'receipt_schema', 'ready_schema', 'termination_protocol_id',
                'ready_marker_prefix', 'self_relationship', 'descendant_relationship'):
        require(type(process[key]) is str and re.fullmatch('[A-Za-z][A-Za-z0-9_ ]*', process[key]) is not None)
    require(process['self_relationship'] != process['descendant_relationship'])
    require(type(process['maximum_chain_nodes']) is int and 1 <= process['maximum_chain_nodes'] <= 64)
    roles = process['roles']
    require(type(roles) is list and len(roles) == 2 and all(type(role) is str and
            re.fullmatch('[a-z][a-z0-9_]*', role) is not None for role in roles) and len(set(roles)) == 2)


CONTRACT = load_contract()
PROCESS = CONTRACT['process']


def generated_sources(contract):
    validate_contract(contract)
    # JSON strings are valid here in GDScript; validation excludes executable text.
    encoded = lambda value: json.dumps(value, ensure_ascii=True)
    gd = ['# Generated from sdk/core/contracts/recovery_interfaces_v1.json; do not edit.',
          'extends RefCounted', '',
          'const CANONICAL_OWNERS = ' + encoded([row['wire_name'] for row in contract['canonical_owners']]),
          'const NO_ACTUATION_MAPPING = ' + encoded(contract['no_actuation_mapping']),
          'const RECOVERY_CONTROLLER_ID = ' + encoded(contract['recovery_controller_id'])]
    ps = ['# Generated from sdk/core/contracts/recovery_interfaces_v1.json; do not edit.',
          'function Get-SporeRecoveryProcessContractV1 {', '    return [ordered]@{']
    for key, value in contract['process'].items():
        if type(value) is int:
            literal = str(value)
        elif type(value) is list:
            literal = '@(' + ', '.join("'" + item + "'" for item in value) + ')'
        else:
            literal = "'" + value + "'"
        ps.append('        ' + key + ' = ' + literal)
    ps += ['    }', '}']
    return {GDSCRIPT_PATH: '\n'.join(gd) + '\n', POWERSHELL_PATH: '\n'.join(ps) + '\n'}


def verify_generated(sources=None):
    for path, expected in (sources or generated_sources(CONTRACT)).items():
        if path.read_text(encoding='utf-8') != expected:
            raise ValueError('RECOVERY_INTERFACE_GENERATED_DRIFT:' + path.relative_to(SDK).as_posix())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    sources = generated_sources(CONTRACT)
    if args.write:
        for path, source in sources.items():
            path.write_text(source, encoding='utf-8', newline='\n')
    verify_generated(sources)
    print('RECOVERY_INTERFACE_GENERATED_CHECK_PASS')


if __name__ == '__main__':
    main()
