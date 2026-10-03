"""Serialized native leaves. Behavior negatives continue; infrastructure failures stop."""
import argparse
import os
from pathlib import Path
import subprocess
import time
import traceback
import r10dh_contract as C
import r10dh_campaign as Campaign
import r10dh_dependency_manifest as M
from r10dh_dependency_manifest import D
import r10dh_authority as A
import r10v_windows_job as W
import recovery_owned_cleanup_v1 as Cleanup


def run_leaf(batch, row, operation, qualification_only=False):
    path = Path(row['folder'])/'declaration.json'
    value = Campaign.validate_cell(path, qualification_only)
    child = Path(value['children'][0]['evidence_path']); prefix = 'preflight-' if qualification_only else ''
    permit = child/(prefix+'job-permit.json'); job = W.Job(); proc = None
    started = time.monotonic(); failure = ''; code = None
    try:
        command = [value['runtime']['images']['powershell_host']['path'], '-NoProfile', '-File',
            C.ROOT/'sdk/conformance/run_r10dh_campaign.ps1', '-Batch', batch, '-MaximumCells',
            str(len(C.population(value['r10dh_campaign']['mode']))), '-CellId', row['cell']['cell_id'],
            '-OperationReceipt', operation, '-StartPermit', permit]
        if qualification_only: command.append('-QualificationOnly')
        with (child/(prefix+'launcher.stdout.txt')).open('xb') as out, (child/(prefix+'launcher.stderr.txt')).open('xb') as err:
            proc = subprocess.Popen(list(map(str, command)), cwd=C.ROOT, env=Campaign.clean_environment(),
                stdin=subprocess.DEVNULL, stdout=out, stderr=err, creationflags=subprocess.CREATE_NO_WINDOW)
            job.add(proc)
            D.write_new(permit, dict(leaf_pid=proc.pid, leaf_identity=W.identity(proc.pid),
                coordinator_identity=W.current_identity(), child_attempt_id=value['children'][0]['child_attempt_id'], job_bound=True))
            code = proc.wait(timeout=180 if qualification_only else 3090)
            C.require(code == 0, 'LEAF_NONZERO')
    except BaseException:
        failure = traceback.format_exc()
    finally:
        try:
            # Hold the job handle through verified termination/drain. Closing
            # it first leaves only the outer owner to observe asynchronous exit.
            Cleanup.drain(job, W, child/(prefix+'owned-cleanup.json'))
        except BaseException: failure += traceback.format_exc()
        finally:
            job.close()
            if proc is not None and proc.poll() is None:
                proc.kill(); proc.wait(timeout=15)
    result = dict(cell=row['cell'], exit_code=code, ok=not failure, error=failure,
        elapsed_seconds=time.monotonic()-started, cleanup=D.binding(child/(prefix+'owned-cleanup.json')),
        physical_acceptance_authority=False, release_authority=False)
    D.write_new(child/(prefix+'leaf-result.json'), result)
    C.require(result['ok'], 'LEAF_FAILURE_RETAINED')
    return result


def run(batch, maximum, workers, operation, qualification_only=False):
    batch = Path(batch).resolve(); prepared = C.read(batch/'prepared.json'); mode = prepared['mode']
    rows = C.read(batch/'cells.json'); C.validate_population([r['cell'] for r in rows], mode)
    C.require(workers == 1 and maximum == len(rows), 'SERIAL_EXACT_POPULATION')
    lock = C.read(operation)
    C.require(lock['acquired'] is True and lock['owner_process_id'] == os.getppid(), 'MUTEX_OWNER')
    if not qualification_only: A.consume(batch)
    results = []; failure = ''
    try:
        for row in rows:
            run_leaf(batch, row, operation, qualification_only)
            child = Path(row['folder'])/'children'/row['cell']['role']
            if not qualification_only:
                result = C.read(child/'campaign-audit.json')
                C.require(result['valid'] is True and result['cell'] == row['cell'], 'CELL_READER')
                results.append(result)
            print('R10DH_CELL_COMPLETE '+row['cell']['cell_id'], flush=True)
        M.validate(C.read(batch/'manifest.json'))
    except BaseException: failure = traceback.format_exc()
    if qualification_only:
        C.require(not failure, 'PREFLIGHT_FAILED:'+failure)
        return
    value = dict(schema_version='sporespore_r10dh_supervisor_v1', ledger_scope=C.SCOPE, mode=mode,
        ok=not failure, error=failure, cells=results, source_unchanged=not failure,
        decision=C.decide(results, mode, not failure),
        physical_acceptance_authority=False, release_authority=False)
    D.write_new(batch/'supervisor-result.json', value)
    C.require(not failure, 'SUPERVISOR_FAILURE_RETAINED')


if __name__ == '__main__':
    p=argparse.ArgumentParser(); p.add_argument('batch'); p.add_argument('--workers',type=int,required=True)
    p.add_argument('--maximum',type=int,required=True); p.add_argument('--operation',required=True)
    p.add_argument('--qualification-only',action='store_true'); a=p.parse_args()
    run(a.batch,a.maximum,a.workers,a.operation,a.qualification_only)
