"""One mutex-owning coordinator, bounded fresh children in kill-on-close jobs."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

import recovery_discovery as D
sys.path.insert(0, str(D.ROOT / 'sdk/conformance'))
import r10v_windows_job as W


def run_cell(batch, row, operation_path, stop, qualification_only=False):
    folder = Path(row['folder'])
    declaration = D.read(folder / 'declaration.json')
    child = Path(declaration['children'][0]['evidence_path'])
    if stop.is_set(): return dict(cell=row['cell'], launched=False)
    prefix = 'preflight-' if qualification_only else ''
    permit = child / (prefix + 'job-permit.json')
    job = W.Job()
    start = time.monotonic()
    proc = None
    try:
        with (child / (prefix+'launcher.stdout.txt')).open('xb') as out, (child / (prefix+'launcher.stderr.txt')).open('xb') as err:
            command = [declaration['runtime']['images']['powershell_host']['path'], '-NoProfile', '-File',
                str(D.HERE / 'run_recovery_discovery.ps1'), '-Batch', str(batch), '-CellId', row['cell']['cell_id'],
                '-OperationReceipt', str(operation_path), '-StartPermit', str(permit)]
            if qualification_only: command.append('-QualificationOnly')
            proc = subprocess.Popen(command,
                cwd=D.ROOT, env=D.clean_environment(), stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
            # The leaf waits for this file before launching Godot. No descendant
            # can be created before containment has actually been assigned.
            job.add(proc)
            D.write_new(permit, dict(leaf_pid=proc.pid, leaf_identity=W.identity(proc.pid), coordinator_identity=W.current_identity(),
                        child_attempt_id=declaration['children'][0]['child_attempt_id'], job_bound=True))
            try:
                code = proc.wait(timeout=declaration['timeout_seconds_per_child'] + declaration.get('reader_timeout_seconds',0) + 90)
            except subprocess.TimeoutExpired:
                job.terminate()
                code = proc.wait(timeout=10)
                stop.set()
            result = dict(cell=row['cell'], launched=True, exit_code=code, seconds=time.monotonic()-start,
                          remaining_owned_pids=job.pids())
            D.write_new(child / (prefix+'pool-process.json'), result)
            if code != 0: stop.set()
            print('LEAF_FINISHED ' + row['cell']['cell_id'] + ' code=' + str(code), flush=True)
            return result
    finally:
        job.close()
        if proc is not None and proc.poll() is None:
            proc.wait(timeout=10)


def run(batch, workers, maximum, operation, qualification_only=False):
    batch = Path(batch)
    source = D.verify_manifest(batch / 'manifest.json')
    D.require(1 <= workers <= source['design']['maximum_workers'] <= 4, 'POOL_BOUND')
    rows = [r for r in D.read(batch/'cells.json') if not (Path(D.read(Path(r['folder'])/'declaration.json')['children'][0]['evidence_path'])/'launch-reservation.json').exists()][:maximum]
    D.require(rows and 1 <= maximum <= 24, 'FRESH_CELLS')
    receipt = D.read(operation)
    D.require(receipt['acquired'] is True and receipt['owner_process_id'] == os.getppid(), 'COORDINATOR_MUTEX_OWNER')
    stop = threading.Event()
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(run_cell,batch,row,operation,stop,qualification_only) for row in rows]
        try:
            for future in as_completed(futures):
                result = future.result()
                if result.get('launched') and result.get('exit_code') != 0:
                    stop.set()
        except BaseException:
            stop.set()
            raise
    # Each leaf has finished its own cold reader; only aggregate their receipts.
    if not qualification_only:
        if source['design']['schema_version'] in ('sporespore_full_recovery_discovery_panel_v1','sporespore_full_recovery_discovery_panel_v2'):
            from recovery_panel_reader import audit_batch
        else:
            from recovery_discovery_reader import audit_batch
        audit_batch(batch)
    D.require(not stop.is_set(),'POOL_CHILD_FAILURE_RETAINED')


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('batch',type=Path);p.add_argument('--workers',type=int,required=True)
    p.add_argument('--maximum',type=int,required=True);p.add_argument('--operation',type=Path,required=True)
    a=p.parse_args();run(a.batch,a.workers,a.maximum,a.operation)
