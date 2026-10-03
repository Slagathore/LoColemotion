"""Check literal Rust compile-time data against the declared SDK inventory."""
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]


def check(root=ROOT):
    sdk=root/'sdk'
    inventory=json.loads((sdk/'release/quadruped_package_source_inventory_v1.json').read_text())
    selected=set(subprocess.check_output(['git','ls-files','--',*inventory['git_pathspecs']],cwd=root,text=True).splitlines())
    references=[]
    for source in sorted((sdk/'core').rglob('*.rs')):
        raw=source.read_text()
        literals=re.findall(r'include_(?:str|bytes)!\(\s*"([^"\n]+)"\s*\)',raw)
        if len(literals)!=len(re.findall(r'include_(?:str|bytes)!\(',raw)):
            raise ValueError('Uncovered compile-time include form: '+str(source))
        for relative in literals:
            target=(source.parent/relative).resolve()
            if not target.is_relative_to(sdk.resolve()):raise ValueError('Core resource escapes SDK: '+relative)
            name=target.relative_to(root).as_posix()
            if name not in selected or not target.is_file():raise ValueError('Core resource missing from package inventory: '+name)
            references.append(dict(source=source.relative_to(root).as_posix(),resource=name))
    if not references:raise ValueError('No compile-time resources checked')
    return dict(ok=True,literal_resource_references=len(references),unique_resources=len({r['resource'] for r in references}),world_build_count=0)


if __name__=='__main__':print(json.dumps(check()))
