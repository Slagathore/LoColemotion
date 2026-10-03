"""Exercise the real native-to-Python identity wire before any physical launch."""
import copy
from pathlib import Path
import r10dh_contract as C
from r10dh_dependency_manifest import D


def validate(folder):
    import r10dh_reader as Reader
    folder = Path(folder)
    declaration = C.read(folder/'declaration.json')
    receipt = C.read(folder/'header-wire.json')
    C.require(receipt['test_only'] is True and receipt['world_build_count'] == receipt['solver_step_count'] == 0,
              'HEADER_WIRE_FIXTURE')
    report = receipt['header']
    C.require(report['synthetic_test_fixture'] is True, 'HEADER_WIRE_LABEL')
    Reader.validate_report_header(report, declaration)
    # Value-preserving float conversion reproduces the original failure. Boolean
    # aliasing, fractional metadata, wrong labels and crossed attempts must also fail.
    corruptions = []
    for key, value in [('seed',float(report['r10dh_campaign']['seed']['seed'])),('prefix_phase',True)]:
        bad=copy.deepcopy(report);bad['r10dh_campaign']['seed'][key]=value;corruptions.append(bad)
    for key in ('manifest','task_contract','design'):
        for value in (float(report['r10dh_campaign'][key]['byte_length']),True,1.5):
            bad=copy.deepcopy(report);bad['r10dh_campaign'][key]['byte_length']=value;corruptions.append(bad)
    for key,value in [('child_attempt_id','crossed'),('parent_attempt_id','crossed'),('seed_label','crossed'),
                      ('held_out',not report['held_out']),('world_build_count',True),('official_qualification',True)]:
        bad=copy.deepcopy(report);bad[key]=value;corruptions.append(bad)
    for bad in corruptions:
        try: Reader.validate_report_header(bad,declaration)
        except ValueError: pass
        else: raise ValueError('R10DH_HEADER_WIRE_CORRUPTION_ACCEPTED')
    return dict(ok=True,test_only=True,accepted_headers=1,rejected_corruptions=len(corruptions),
        declaration=D.binding(folder/'declaration.json'),wire=D.binding(folder/'header-wire.json'),
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def run(folder, engine):
    folder=Path(folder)
    D.process(folder,'header-wire',[engine,'--headless','--path',C.ROOT,'--script',
        'res://sdk/adapters/godot/gdscript/test_r10dh_header_wire_v2.gd','--',folder/'declaration.json',folder/'header-wire.json'],timeout=60)
    result=validate(folder)
    D.write_new(folder/'header-wire-audit.json',result)
    return result
