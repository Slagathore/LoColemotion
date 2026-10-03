"""Lossless NTFS maintenance of exactly closed recovery evidence populations.

No files are moved, removed, rewritten, or marked for inherited compression.
--pilot exercises compression, reader compatibility, decompression and a final
compression on V44's report. --all only follows a successful retained pilot.
"""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent/'SporeSpore_Evidence'
PILOT_ID = 'b308b58a36144525866e2f96b2abe0be'
SUFFIXES = {'.json', '.jsonl', '.stdout', '.stderr', '.txt', '.log'}
FLAGS = dict(physical_acceptance_authority=False, release_authority=False,
             new_world_count=0, new_solver_step_count=0)
KERNEL = ctypes.WinDLL('kernel32', use_last_error=True)
KERNEL.GetCompressedFileSizeW.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.DWORD)]
KERNEL.GetCompressedFileSizeW.restype = wintypes.DWORD
KERNEL.GetFileAttributesW.argtypes = [wintypes.LPCWSTR]
KERNEL.GetFileAttributesW.restype = wintypes.DWORD
KERNEL.CreateMutexW.argtypes = [ctypes.c_void_p, wintypes.BOOL, wintypes.LPCWSTR]
KERNEL.CreateMutexW.restype = wintypes.HANDLE
KERNEL.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
KERNEL.ReleaseMutex.argtypes = [wintypes.HANDLE]
KERNEL.CloseHandle.argtypes = [wintypes.HANDLE]


def require(value, code):
    if not value:
        raise ValueError('CLOSED_EVIDENCE_' + code)


def encode(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True, allow_nan=False).encode('ascii')


def write(path, value):
    with path.open('xb') as out:
        out.write(encode(value)+b'\n')


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(path):
    hashed = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8*1024*1024), b''):
            hashed.update(block)
    return hashed.hexdigest()


def binding(path):
    return dict(path=str(path), byte_length=path.stat().st_size, sha256='sha256:'+digest(path))


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True, encoding='utf-8').strip()


def identity():
    require(Path(git('rev-parse','--show-toplevel')).resolve() == ROOT, 'ROOT')
    require(git('remote','get-url','origin') == 'https://github.com/Slagathore/sporespore.git', 'REMOTE')
    return dict(commit=git('rev-parse','HEAD'), status=git('status','--short'))


def safe(path):
    require(path.resolve().is_relative_to(EVIDENCE.resolve()), 'OUTSIDE_EVIDENCE')
    attrs = KERNEL.GetFileAttributesW(str(path))
    require(attrs != 0xffffffff and not (attrs & 0x400), 'REPARSE_OR_MISSING:' + str(path))
    return attrs


def disk_bytes(path):
    safe(path)
    high = wintypes.DWORD()
    ctypes.set_last_error(0)
    low = KERNEL.GetCompressedFileSizeW(str(path), ctypes.byref(high))
    require(low != 0xffffffff or ctypes.get_last_error() == 0, 'DISK_SIZE')
    # Selected files exceed 64 KiB and reside on this verified 4-KiB NTFS volume.
    return math.ceil(((high.value << 32) | low)/4096)*4096


def inventory(root):
    safe(root)
    result = []
    for path in sorted(root.rglob('*')):
        safe(path)
        if path.is_file():
            result.append(dict(path=path.relative_to(root).as_posix(),
                               byte_length=path.stat().st_size, sha256=digest(path)))
    return result


def closed_population(record_path):
    record = read(record_path)
    root = Path(record['evidence_root']).resolve()
    require(root.parent == EVIDENCE.resolve() and root.name == 'development-recovery-smoke-'+record['attempt_id'], 'ATTEMPT_ROOT')
    require(record['status'].startswith('closed_consumed_'), 'ATTEMPT_OPEN')
    original = inventory(root)
    expected = record['retained_population']
    require(len(original) == expected['file_count'] and sum(x['byte_length'] for x in original) == expected['byte_length'] and
            'sha256:'+hashlib.sha256(encode(original)).hexdigest() == expected['inventory_sha256'], 'ORIGINAL_INVENTORY:'+record['attempt_id'])
    return record, root, original


def compact(path, compressed, output, label):
    safe(path)
    before = binding(path)
    command = [str(Path(os.environ['SystemRoot'])/'System32/compact.exe'), '/c' if compressed else '/u', '/q', str(path)]
    with (output/(label+'.stdout')).open('xb') as stdout, (output/(label+'.stderr')).open('xb') as stderr:
        child = subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            code = child.wait(timeout=120)
        except subprocess.TimeoutExpired:
            child.kill(); child.wait(timeout=10)
            raise ValueError('CLOSED_EVIDENCE_COMPACT_TIMEOUT')
    require(code == 0 and binding(path) == before, 'COMPACT_EXIT_OR_BYTES')
    require(bool(safe(path) & 0x800) is compressed, 'COMPRESSION_ATTRIBUTE')


def pilot(output):
    record_path = ROOT/'sdk/development/recovery_attempts'/(PILOT_ID+'.json')
    record, root, original = closed_population(record_path)
    path = root/'children/kick_passive_recovery_resume/worker_report.json'
    initial = dict(binding=binding(path), disk_bytes=disk_bytes(path), compressed=bool(safe(path)&0x800))
    require(not initial['compressed'], 'PILOT_ALREADY_COMPRESSED')
    write(output/'pilot-before.json', dict(record=binding(record_path), initial=initial, inventory=original))
    compact(path, True, output, 'pilot-compress')
    compressed_bytes = disk_bytes(path)
    with (output/'reader.stdout').open('xb') as stdout, (output/'reader.stderr').open('xb') as stderr:
        child = subprocess.Popen([sys.executable, str(ROOT/'tests/test_development_v44_support_diagnosis.py')],
            cwd=ROOT, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            code = child.wait(timeout=120)
        except subprocess.TimeoutExpired:
            child.kill(); child.wait(timeout=10)
            raise ValueError('CLOSED_EVIDENCE_READER_TIMEOUT')
    require(code == 0, 'COMPRESSED_READER')
    compact(path, False, output, 'pilot-decompress')
    require(disk_bytes(path) == initial['disk_bytes'], 'RESTORE_DISK_SIZE')
    compact(path, True, output, 'pilot-recompress')
    require(inventory(root) == original, 'PILOT_FINAL_INVENTORY')
    return dict(status='pilot_complete', record=binding(record_path), file=binding(path),
        original_disk_bytes=initial['disk_bytes'], compressed_disk_bytes=compressed_bytes,
        disk_bytes_recovered=initial['disk_bytes']-compressed_bytes, original_inventory_preserved=True,
        existing_reader_tests_passed=3, decompression_restore_verified=True, **FLAGS)


def compress_all(output, pilot_receipt):
    safe(pilot_receipt)
    p = read(pilot_receipt)
    require(p['status'] == 'pilot_complete' and p['existing_reader_tests_passed'] == 3 and
            p['original_inventory_preserved'] is True and p['decompression_restore_verified'] is True, 'PILOT_NOT_PASSED')
    require(binding(Path(p['file']['path'])) == p['file'] and
            binding(Path(p['record']['path'])) == p['record'], 'PILOT_BINDINGS')
    eligible, skipped = [], []
    for path in sorted((ROOT/'sdk/development/recovery_attempts').glob('*.json')):
        r = read(path); population = r.get('retained_population', {})
        if isinstance(r.get('evidence_root'),str) and 'development-recovery-smoke-' in r['evidence_root']:
            if (r.get('status','').startswith('closed_consumed_') and set(population) == {'file_count','byte_length','inventory_sha256'}):
                eligible.append(path)
            else:
                skipped.append(dict(record=binding(path), reason='No exact full-population inventory in the supported closure schema.'))
    require(eligible and sum(read(p)['retained_population']['byte_length'] for p in eligible) < 40_000_000_000, 'SCOPE_BOUND')
    declaration = dict(records=[binding(p) for p in eligible], skipped=skipped, pilot=binding(pilot_receipt),
        minimum_file_bytes=65536, extensions=sorted(SUFFIXES), directories_modified=False,
        source_binaries_modified=False, paths_or_logical_bytes_changed=False, **FLAGS)
    write(output/'declaration.json', declaration)
    completed = []
    with (output/'progress.jsonl').open('xb') as progress:
        for record_path in eligible:
            print('VERIFY_AND_COMPRESS', record_path.stem, flush=True)
            record, root, original = closed_population(record_path)
            selected = [root/x['path'] for x in original if x['byte_length'] >= 65536 and (root/x['path']).suffix.lower() in SUFFIXES]
            before = [dict(binding=binding(path), disk_bytes=disk_bytes(path), compressed=bool(safe(path)&0x800)) for path in selected]
            write(output/(record_path.stem+'-before.json'), dict(record=binding(record_path), inventory=original, selected=before))
            for index, path in enumerate(selected):
                if not before[index]['compressed']:
                    compact(path, True, output, record_path.stem+'-'+str(index))
            require(inventory(root) == original, 'FINAL_INVENTORY:'+record_path.stem)
            after = sum(disk_bytes(path) for path in selected)
            row = dict(attempt_id=record_path.stem, complete_inventory_reverified=True, file_count=len(original),
                logical_bytes=record['retained_population']['byte_length'], selected_files=len(selected),
                selected_logical_bytes=sum(x['binding']['byte_length'] for x in before),
                disk_bytes_before=sum(x['disk_bytes'] for x in before), disk_bytes_after=after,
                disk_bytes_recovered=sum(x['disk_bytes'] for x in before)-after)
            completed.append(row); progress.write(encode(row)+b'\n'); progress.flush()
            print('VERIFIED', row['attempt_id'], 'recovered_bytes', row['disk_bytes_recovered'], flush=True)
    return dict(status='compression_complete', declaration=binding(output/'declaration.json'),
        closed_attempts=len(completed), results=completed, skipped=skipped,
        disk_bytes_recovered=sum(x['disk_bytes_recovered'] for x in completed),
        selected_files=sum(x['selected_files'] for x in completed), all_original_inventories_preserved=True, **FLAGS)


def main():
    parser = argparse.ArgumentParser(__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--pilot', action='store_true'); modes.add_argument('--all', type=Path, metavar='PILOT_RECEIPT')
    args = parser.parse_args()
    output = EVIDENCE/('closed-evidence-ntfs-maintenance-'+uuid.uuid4().hex)
    output.mkdir(exist_ok=False)
    result = dict(status='maintenance_refused_or_incomplete', evidence_root=str(output), **FLAGS)
    handle = None; acquired = False
    try:
        initial_identity = identity()
        handle = KERNEL.CreateMutexW(None, False, r'Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1')
        require(handle, 'LOCK_CREATE')
        acquired = KERNEL.WaitForSingleObject(handle, 0) in (0,0x80)
        require(acquired, 'OPERATION_BUSY')
        write(output/'source.json', dict(source=initial_identity, implementation=binding(Path(__file__)),
            executable=binding(Path(sys.executable)), compact=binding(Path(os.environ['SystemRoot'])/'System32/compact.exe')))
        with (output/'tested-source.py').open('xb') as stream: stream.write(Path(__file__).read_bytes())
        result.update(pilot(output) if args.pilot else compress_all(output, args.all.resolve()))
        require(identity() == initial_identity, 'SOURCE_DRIFT')
    except Exception as error:
        result.update(status='maintenance_refused_or_incomplete', error=str(error))
    finally:
        if acquired: KERNEL.ReleaseMutex(handle)
        if handle: KERNEL.CloseHandle(handle)
    write(output/'receipt.json', result)
    print(json.dumps(result), flush=True)
    return 0 if result['status'] in ('pilot_complete','compression_complete') else 1


if __name__ == '__main__':
    sys.exit(main())
