"""Unofficial visible diagnostic owner. One native child, bounded, kill-on-close job."""
import ctypes as C
from ctypes import wintypes as T
import json,os,subprocess,sys,time,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10v_windows_job as W
cfg_path=Path((Path(__file__).parent/'active_config.txt').read_text(encoding='utf-8'))
cfg=json.loads(cfg_path.read_text(encoding='utf-8')); folder=cfg_path.parent
assert subprocess.check_output(['git','rev-parse','--show-toplevel'],cwd=ROOT,text=True).strip().replace('\\','/')==ROOT.as_posix()
assert subprocess.check_output(['git','remote','get-url','origin'],cwd=ROOT,text=True).strip()=='https://github.com/Slagathore/LoColemotion.git'
for image in cfg['images'].values(): assert hashlib.sha256(Path(image['path']).read_bytes()).hexdigest()==image['sha256']
create=W.api('CreateMutexW',[C.c_void_p,T.BOOL,T.LPCWSTR],T.HANDLE)
release=W.api('ReleaseMutex',[T.HANDLE])
mutex=W.checked(create(None,False,'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'))
if W.wait(mutex,0) not in (0,128): raise RuntimeError('Another native operation owns the mutex')
job=W.Job()
env={k:v for k,v in os.environ.items() if not k.startswith('SPORESPORE_')}
env['SPORESPORE_VISUAL_DIAGNOSTIC_CONFIG']=str(cfg_path)
command=[cfg['images']['engine']['path'],'--path',str(ROOT),'--script','res://sdk/explorer/phase74_diagnostic/viewer.gd']
try:
 if '--check' in sys.argv:
  command.insert(1,'--headless');command+=['--','--check']
 with (folder/('check2.stdout.log' if '--check' in sys.argv else 'live.stdout.log')).open('w',encoding='utf-8') as out,(folder/('check2.stderr.log' if '--check' in sys.argv else 'live.stderr.log')).open('w',encoding='utf-8') as err:
  child=subprocess.Popen(command,cwd=ROOT,env=env,stdout=out,stderr=err)
  job.add(child)
  if '--check' not in sys.argv:
   with Path(cfg['permit']).open('x') as f: f.write(str(child.pid))
  print(json.dumps({'pid':child.pid,'folder':str(folder),'visible':'--check' not in sys.argv}),flush=True)
  try: code=child.wait(timeout=180 if '--check' in sys.argv else 3600)
  except subprocess.TimeoutExpired: job.terminate();child.wait();code=124
  print('EXIT',code,flush=True)
finally:
 job.close();release(mutex);W.close(mutex)
