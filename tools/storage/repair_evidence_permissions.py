"""Restore each copied ordinary entry's DACL without propagating through links."""
import argparse
import ctypes
from ctypes import wintypes
from functools import lru_cache
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import stat
import time

import verify_evidence_copy as storage

SCOPE = dict(subsystem="storage", engine_scope="core", authority_mode="development", question_class="development")


@lru_cache(maxsize=1)
def setter_api():
    api, kernel = storage.security_api()
    pointer = ctypes.c_void_p
    convert = api.ConvertStringSecurityDescriptorToSecurityDescriptorW
    convert.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, ctypes.POINTER(pointer), pointer]
    convert.restype = wintypes.BOOL
    setter = api.SetFileSecurityW
    setter.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, pointer]
    setter.restype = wintypes.BOOL
    return convert, setter, kernel


def set_access_rules(path, sddl, root):
    """Set only this ordinary entry; reject every link in its destination path."""
    root = storage.ordinary_root(root)
    storage.require(root.resolve(strict=True) == root, "Aliased permission root")
    path = Path(os.path.abspath(path))
    storage.require(path != root and path.is_relative_to(root), "Permission target escaped root")
    current = root
    for component in path.relative_to(root).parts:
        current /= component
        info = current.lstat()
        storage.require(not info.st_file_attributes & storage.REPARSE, "Linked permission target: "+str(current))
        storage.require(stat.S_ISDIR(info.st_mode) or (current == path and stat.S_ISREG(info.st_mode)), "Nonordinary permission target")
    convert, setter, kernel = setter_api()
    descriptor = ctypes.c_void_p()
    storage.require(convert(sddl, 1, ctypes.byref(descriptor), None), "Cannot decode source DACL")
    try:
        # This legacy API is deliberate: unlike SetNamedSecurityInfo it does
        # not propagate directory ACLs into children or stored junction targets.
        # https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-setfilesecurityw
        storage.require(setter(str(path), 4, descriptor),
            "Cannot restore copied DACL: "+str(path)+" error="+str(ctypes.get_last_error()))
    finally:
        kernel.LocalFree(descriptor)


def repair(source, destination, database, output):
    source, destination = storage.ordinary_root(source), storage.ordinary_root(destination)
    storage.require(source.resolve(strict=True) == source and destination.resolve(strict=True) == destination,
        "Aliased repair root")
    storage.require(source != destination and not source.is_relative_to(destination)
        and not destination.is_relative_to(source), "Overlapping repair roots")
    with sqlite3.connect(database) as connection:
        storage.require(connection.execute("SELECT value FROM metadata WHERE key='source'").fetchone() == (str(source),), "Crossed repair manifest")
        expected = {r[0]: r[1:] for r in connection.execute("SELECT path,kind,size,mtime_ns,link_target FROM entries")}
    output.mkdir()
    started = last = time.monotonic()
    result = dict(ok=False, ledger_scope=SCOPE, entries_checked=0, ordinary_entries_checked=0,
        entries_repaired=0, source_changed=False, data_bytes_changed=False, follows_links=False)
    unseen = set(expected)
    journal_path = output/"changes.jsonl"
    try:
        with journal_path.open("x", encoding="utf-8", newline="\n") as journal:
            pending = []
            def event(value):
                journal.write(json.dumps(value)+"\n")

            def sync():
                journal.flush()
                os.fsync(journal.fileno())

            def flush_batch():
                # Persist every original DACL in the bounded batch before its
                # first mutation. Avoid two disk barriers for every tiny file.
                for relative, original, before in pending:
                    event(dict(event="before",path=relative,source_dacl=original,destination_dacl=before))
                sync()
                try:
                    for relative, original, before in pending:
                        target=destination/relative
                        storage.require(storage.access_rules(source/relative) == original, "Source DACL changed before repair")
                        storage.require(storage.access_rules(target) == before, "Destination DACL changed before repair")
                        set_access_rules(target,original,destination)
                        after=storage.access_rules(target)
                        event(dict(event="after",path=relative,destination_dacl=after))
                        storage.require(storage.access_key(original) == storage.access_key(after), "DACL repair did not preserve rules: "+relative)
                        storage.require(storage.access_rules(source/relative) == original, "Source DACL changed")
                        result["entries_repaired"] += 1
                finally:
                    sync()
                pending.clear()
            for row in storage.entries(source):
                relative, kind, size, mtime, link = row
                storage.require(relative in unseen and tuple(row[1:]) == tuple(expected[relative]), "Source changed before ACL repair: "+relative)
                unseen.remove(relative)
                target = destination/relative
                info = target.lstat()
                if kind == "link":
                    storage.require(info.st_file_attributes & storage.REPARSE
                        and info.st_reparse_tag == size and os.readlink(target) == link, "Copied link changed: "+relative)
                else:
                    storage.require(not info.st_file_attributes & storage.REPARSE, "Copied entry became a link: "+relative)
                    storage.require((kind == "directory" and stat.S_ISDIR(info.st_mode))
                        or (kind == "file" and stat.S_ISREG(info.st_mode)
                            and (info.st_size, info.st_mtime_ns) == (size, mtime)), "Copied entry changed: "+relative)
                    original = storage.access_rules(source/relative)
                    before = storage.access_rules(target)
                    if storage.access_key(original) != storage.access_key(before):
                        pending.append((relative,original,before))
                        if len(pending) == 100:
                            flush_batch()
                    result["ordinary_entries_checked"] += 1
                result["entries_checked"] += 1
                if time.monotonic()-last >= 15:
                    print(json.dumps(dict(stage="permissions", **result, elapsed_s=time.monotonic()-started)), flush=True)
                    last = time.monotonic()
            if pending:
                flush_batch()
        storage.require(not unseen, "Source paths missing during ACL repair")
        result["ok"] = True
    except BaseException as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"
        raise
    finally:
        result["wall_s"] = time.monotonic()-started
        with journal_path.open("rb") as stream:
            result["changes_sha256"] = hashlib.file_digest(stream,"sha256").hexdigest()
        storage.write_new(output/"receipt.json",result)
        print(json.dumps(result),flush=True)
    return result


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ["source","destination","database","output"]:
        parser.add_argument("--"+name,type=Path,required=True)
    args=parser.parse_args()
    repair(args.source,args.destination,args.database,args.output)
