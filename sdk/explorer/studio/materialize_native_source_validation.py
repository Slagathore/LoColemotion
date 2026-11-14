"""Use the qualified pure validator in an isolated short native Studio route."""
from pathlib import Path
import hashlib
import shutil

STUDIO=Path(__file__).resolve().parent
ROOT=STUDIO.parents[2]


def install_image(project,library,expected_sha256):
    """Install the same pure helper and preserved predicate used by CPU replay."""
    library=library.resolve()
    if not library.is_relative_to((ROOT.parent/'SporeSpore_Evidence').resolve()) or hashlib.sha256(library.read_bytes()).hexdigest()!=expected_sha256:
        raise ValueError('Native validator image binding')
    collection=project/'sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd'
    source=collection.read_text(encoding='utf-8-sig')
    if source.count('static func _json_source_v1(')!=1 or '_studio_reference_json_source_v1(' in source:
        raise ValueError('Native validator predicate boundary changed')
    begin=source.index('static func _json_source_v1(')
    source=source[:begin]+source[begin:].replace('_json_source_v1(','_studio_reference_json_source_v1(')
    source+='''
static var studio_native_validator: Object
static var studio_native_validation_enabled: bool = false

static func _json_source_v1(value: Variant, depth: int = 0, source_link: bool = false) -> bool:
\tif studio_native_validation_enabled:
\t\treturn studio_native_validator.validate_source_v1(value,depth,source_link)
\treturn _studio_reference_json_source_v1(value,depth,source_link)
'''
    destination=project/'sdk/explorer/studio/native_validation'
    destination.mkdir(exist_ok=False)
    shutil.copy2(library,destination/'validator.dll')
    (destination/'validator.gdextension').write_text(
        '[configuration]\nentry_symbol="gdext_rust_init"\ncompatibility_minimum="4.7"\n'
        '[libraries]\nwindows.x86_64="res://sdk/explorer/studio/native_validation/validator.dll"\n',encoding='utf-8',newline='\n')
    collection.write_text(source,encoding='utf-8',newline='\n')
    shutil.copy2(STUDIO/'test_native_source_validation.gd',destination.parent/'test_native_source_validation.gd')


def requested(args):
    library=getattr(args,'native_validator',None)
    digest=getattr(args,'native_validator_sha256',None)
    policy=getattr(args,'source_validation_policy','original')
    if bool(library)!=bool(digest) or policy not in ('original','native'):
        raise ValueError('Native validator image, digest and policy must agree')
    if not library:
        if policy!='original':raise ValueError('Native policy requires a validator image')
        return None
    if not args.live_walking or args.walking_steps!=119 or getattr(args,'serializer_cache_policy','clear_all')!='clear_all' or any(getattr(args,name,False) for name in
            ('bridge_profile','startup_packets','probe_impulses','epoch_boundary_probe','energy_epoch_probe','live_handoff')):
        raise ValueError('Native validation requires the unprofiled short live route without other probes')
    return dict(policy=policy,library=Path(library),sha256=digest)


def materialize(project,library,digest,policy):
    if policy not in ('original','native'):raise ValueError('Native validator policy')
    worker=project/'sdk/explorer/native_recovery/worker.gd'
    source=worker.read_text(encoding='utf-8-sig')
    entry='func _verify_l15_prepared_context_before_world_v1() -> bool:\n'
    parent='\treturn super._verify_l15_prepared_context_before_world_v1()'
    complete='\tif value.get("message_type")=="completed":\n'
    if source.count(entry)!=1 or source.count(parent)!=1 or source.count(complete)!=1:
        raise ValueError('Native validator worker boundary changed')
    install_image(project,library,digest)
    collection=project/'sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd'
    text=collection.read_text()
    text=text.replace('static var studio_native_validator: Object',
        'static var studio_original_validation_calls: int = 0\nstatic var studio_compiled_validation_calls: int = 0\nstatic var studio_native_validator: Object',1)
    text=text.replace('\t\treturn studio_native_validator.validate_source_v1(value,depth,source_link)',
        '\t\tstudio_compiled_validation_calls += 1\n\t\treturn studio_native_validator.validate_source_v1(value,depth,source_link)',1)
    text=text.replace('\treturn _studio_reference_json_source_v1(value,depth,source_link)',
        '\tstudio_original_validation_calls += 1\n\treturn _studio_reference_json_source_v1(value,depth,source_link)',1)
    collection.write_text(text,encoding='utf-8',newline='\n')
    source=source.replace(entry,entry+f'''\t_source_validation = StudioSourceValidation.initialize(ValidationCollection,"{policy}")
\tif not _source_validation.get("ok",false):
\t\t_abort("SOURCE_VALIDATION_PREFLIGHT_FAILED",_source_validation);return false
''',1)
    source=source.replace(parent,'''\tvar accepted := super._verify_l15_prepared_context_before_world_v1()
\tif accepted and not _check_only:StudioSourceValidation.reset_counts(ValidationCollection)
\treturn accepted''',1)
    source=source.replace(complete,complete+'''\t\tvalue.summary["studio_source_validation"] = StudioSourceValidation.summary(ValidationCollection,_source_validation)
''',1)
    source+='''
const StudioSourceValidation := preload("res://sdk/explorer/studio/native_source_validation.gd")
const ValidationCollection := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd")
var _source_validation: Dictionary = {}
'''
    worker.write_text(source,encoding='utf-8',newline='\n')
    shutil.copy2(STUDIO/'native_source_validation.gd',project/'sdk/explorer/studio/native_source_validation.gd')
    return dict(policy=policy,helper_sha256=digest,oracle_controls=2424,dispatch_controls=4,
        telemetry='Full original capture plus integer validator call counters; no reduced source or solver capture.')


def validate_summary(value,policy,physical):
    def require(condition,message):
        if not condition:raise ValueError(message)
    require(policy in ('original','native') and value['policy']==policy,'Validator policy')
    require(value['ok'] is True and value['preworld_verified'] is True,'Validator preworld gate')
    require(value['version']=='sporespore_finite_source_validation_v1','Validator version')
    controls=value['oracle_controls'];dispatch=value['dispatch_controls']
    require(controls['ok'] is True and type(controls['checks']) is int and controls['checks']==2424 and controls['failures']==[],'Validator oracle controls')
    require(all(type(controls[k]) is int and controls[k]==0 for k in ('world_build_count','solver_steps')),'Validator oracle worlds')
    require(dispatch['ok'] is True and type(dispatch['checks']) is int and dispatch['checks']==4,'Validator dispatch controls')
    for key in ('original_calls','compiled_calls'):
        require(type(value[key]) is int and value[key]>=0,'Validator call counter')
    selected='compiled_calls' if policy=='native' else 'original_calls'
    other='original_calls' if policy=='native' else 'compiled_calls'
    require(value[other]==0 and (not physical or value[selected]>0),'Validator backend execution')
    for key in ('additional_controller_calls','additional_physics_reads','additional_solver_steps'):
        require(type(value[key]) is int and value[key]==0,'Validator side effect claim')
    require(value['physical_acceptance_authority'] is value['release_authority'] is False,'Validator authority claim')
    return dict(ok=True,policy=policy,original_calls=value['original_calls'],compiled_calls=value['compiled_calls'],
        oracle_controls=2424,dispatch_controls=4)
