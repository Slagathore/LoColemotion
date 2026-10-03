"""Make an isolated development successor; original route source stays intact."""
import re
import shutil
from pathlib import Path

STUDIO=Path(__file__).resolve().parent
PATTERN=re.compile(r'static func (\w*context_binding_exact_v1)\(\s*sdk: Object,\s*context: Dictionary,?\s*(expected_controller_id: String = "")?\s*\) -> bool:')


def materialize(project):
    project=project.resolve()
    route=project/'sdk/adapters/godot/gdscript/recovery_native_route_v1.gd'
    original=route.read_text(encoding='utf-8-sig')
    names=[];wrappers=[]
    def wrap(match):
        name=match[1];extra=bool(match[2]);names.append(name)
        arguments='sdk, context'+(', expected_controller_id' if extra else '')
        key='"'+name+'"'+(' + ":" + expected_controller_id' if extra else '')
        declaration=match[0]
        wrappers.append(declaration+'\n'+
            '\tvar native: Object=sdk\n'+
            '\tif is_instance_valid(sdk) and sdk.get_script()!=null:\n'+
            '\t\tif sdk.get_script()!=preload("res://sdk/explorer/native_recovery/memoized_sdk.gd"):\n'+
            f'\t\t\treturn _studio_original_{name}({arguments})\n'+
            '\t\tnative=sdk.native\n'+
            '\tif not is_instance_valid(native) or native.get_class()!="SporeLocomotionSdk" or native.get_script()!=null:\n'+
            f'\t\treturn _studio_original_{name}({arguments})\n'+
            f'\treturn StudioContextCache.check(native,context,{key},func():return _studio_original_{name}({arguments}))\n')
        return declaration.replace('func '+name+'(','func _studio_original_'+name+'(')
    transformed=PATTERN.sub(wrap,original)
    if len(names)!=16:raise ValueError(f'Context predicate population changed: {names}')
    # Only declarations are renamed; internal calls still traverse wrappers.
    transformed+='\nconst StudioContextCache:=preload("res://sdk/explorer/studio/immutable_context_cache.gd")\n\n'+'\n'.join(wrappers)
    route.write_text(transformed,encoding='utf-8',newline='\n')
    target=project/'sdk/explorer/studio';target.mkdir(exist_ok=False)
    for name in ['immutable_context_cache.gd','godot_context_probe.gd']:
        shutil.copy2(STUDIO/name,target/name)
    worker=project/'sdk/explorer/native_recovery/worker.gd'
    shutil.copy2(worker,worker.with_name('worker_base.gd'))
    shutil.copy2(STUDIO/'godot_cached_worker.gd',worker)
    return names
