"""Bounded exploratory inputs. Construction validity never proves behavior."""
import math
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from showcase_model import validate_descriptor

SCHEMA='sporespore_explorer_sandbox_request_v1'


def validate(value):
    expected={'schema_version','descriptor','steps','phase_mode','impulses','realtime'}
    if type(value) is not dict or set(value)!=expected or value['schema_version']!=SCHEMA:
        raise ValueError('Sandbox request schema')
    validate_descriptor(value['descriptor'])
    if type(value['steps']) is not int or not 120<=value['steps']<=7200:raise ValueError('Sandbox horizon must be 120..7200 steps')
    if value['steps']%4:raise ValueError('Sandbox horizon must end on a 30 Hz display sample')
    if value['phase_mode'] not in ('clocked','contact_gated'):raise ValueError('Unknown phase mode')
    if type(value['realtime']) is not bool:raise ValueError('Realtime must be boolean')
    if type(value['impulses']) is not list or len(value['impulses'])>16:raise ValueError('At most 16 impulses')
    previous=0
    for row in value['impulses']:
        if type(row) is not dict or set(row)!={'step','vector_n_s'}:raise ValueError('Impulse schema')
        step=row['step'];vector=row['vector_n_s']
        if type(step) is not int or not previous<step<value['steps']:raise ValueError('Distinct ordered impulse steps inside horizon required')
        if type(vector) is not list or len(vector)!=3 or any(type(n) not in (int,float) or not math.isfinite(n) for n in vector):raise ValueError('Finite impulse vector required')
        if not 0<math.sqrt(sum(n*n for n in vector))<=8:raise ValueError('Impulse norm must be above zero and at most 8 N.s')
        previous=step
    return value
