"""Digest-checked explanatory recipes; loading a recipe never launches physics."""
import json
from pathlib import Path
import sys

SDK=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(SDK/'explorer'))
from showcase_model import sha, generated, runnable


def load():
    value=json.loads((Path(__file__).parent/'scenario_catalog_v1.json').read_text())
    if value['physical_acceptance_authority'] is not False:raise ValueError('Catalog cannot grant acceptance')
    for source in value['sources']:
        path=(SDK/source['path']).resolve()
        if not path.is_relative_to(SDK) or sha(path)!=source['sha256']:raise ValueError('Scenario source missing or changed: '+source['path'])
    for entry in value['entries']:
        descriptor=generated(entry['seed'])
        if entry['engine']!='mujoco':runnable(descriptor,entry['engine'],entry['phase'])
    return value
