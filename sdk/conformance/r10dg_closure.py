"""Append-only R10DG qualification and physical closure; historical receipts stay immutable."""
import argparse
import json
from pathlib import Path
import r10dg_identity as I
import r10dg_safety as S

QUALIFIED = I.ROOT / 'sdk/recovery/r10dg_safety_qualification_v1.json'
PHYSICAL = I.ROOT / 'sdk/recovery/r10dg_physical_diagnostic_v1.json'

def close_qualification(path):
    value = S.verify(path)
    earlier = []
    for folder in sorted([*I.EVIDENCE.glob('r10dg-integration-*'), *I.EVIDENCE.glob('r10dg-safety-*')]):
        earlier.append(dict(execution_root=folder.as_posix(), files=[I.binding(p) for p in sorted(folder.iterdir()) if p.is_file()]))
    I.write_new(QUALIFIED, dict(schema_version='sporespore_r10dg_safety_closure_v1',
        ledger_scope=I.read(I.DESIGN)['ledger_scope'], qualification=I.binding(path),
        complete_applicable_safety_gate_passed=True, stage_count=len(value['stages']),
        earlier_integration_attempts=earlier, physical_attempted=False,
        physical_acceptance_authority=False, release_authority=False))

def close_physical(path):
    path = Path(path).resolve()
    value = I.read(path)
    I.require(value.get('pause_after_attempt') is True, 'PAUSE_BOUNDARY')
    folder = path.parent
    I.write_new(PHYSICAL, dict(schema_version='sporespore_r10dg_physical_diagnostic_closure_v1',
        ledger_scope=I.read(I.DESIGN)['ledger_scope'], audit=I.binding(path), outcome=value,
        evidence=[I.binding(p) for p in sorted(folder.rglob('*')) if p.is_file()],
        paused_after_single_attempt=True, sdk1_score='14/20', physical_acceptance_authority=False, release_authority=False))

def audit():
    qualified = I.read(QUALIFIED)
    I.require(I.binding(qualified['qualification']['path']) == qualified['qualification'], 'QUALIFICATION_CLOSURE')
    S.verify(qualified['qualification']['path'])
    for attempt in qualified['earlier_integration_attempts']:
        for item in attempt['files']: I.require(I.binding(item['path']) == item, 'EARLIER_ATTEMPT')
    result = dict(ok=True, complete_applicable_safety_gate_passed=True, physical_attempted=False)
    if PHYSICAL.exists():
        physical = I.read(PHYSICAL)
        for item in [physical['audit'], *physical['evidence']]: I.require(I.binding(item['path']) == item, 'PHYSICAL_EVIDENCE')
        result.update(physical_attempted=True, outcome=physical['outcome']['disposition'], paused=True)
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--qualify', type=Path)
    parser.add_argument('--physical', type=Path)
    args = parser.parse_args()
    if args.qualify: close_qualification(args.qualify)
    if args.physical: close_physical(args.physical)
    print(json.dumps(audit()))
