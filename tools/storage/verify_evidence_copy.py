"""Inventory and verify an evidence relocation without following stored links.

This program never moves or deletes evidence. The source inventory is created
before copying; verification checks both trees and hashes every ordinary file.
Its SQLite manifest and receipts belong in a durable migration audit directory.
"""
import argparse
import ctypes
from ctypes import wintypes
from functools import lru_cache
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import stat
import time


REPARSE = 0x400
JUNCTION = 0xA0000003
SYMLINK = 0xA000000C


@lru_cache(maxsize=1)
def security_api():
    """Bind the read-only API once for the million-entry archive scan."""
    api = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    pointer = ctypes.c_void_p
    get = api.GetNamedSecurityInfoW
    get.argtypes = [wintypes.LPWSTR, wintypes.DWORD, wintypes.DWORD,
                   pointer, pointer, ctypes.POINTER(pointer), pointer, ctypes.POINTER(pointer)]
    get.restype = wintypes.DWORD
    convert = api.ConvertSecurityDescriptorToStringSecurityDescriptorW
    convert.argtypes = [pointer, wintypes.DWORD, wintypes.DWORD, ctypes.POINTER(pointer), pointer]
    convert.restype = wintypes.BOOL
    kernel.LocalFree.argtypes = [pointer]
    kernel.LocalFree.restype = pointer
    return api, kernel


def access_rules(path):
    """Read the ordinary file/directory DACL without changing its security."""
    api, kernel = security_api()
    pointer = ctypes.c_void_p
    get = api.GetNamedSecurityInfoW
    convert = api.ConvertSecurityDescriptorToStringSecurityDescriptorW
    descriptor, dacl, output = pointer(), pointer(), pointer()
    error = get(str(path), 1, 4, None, None, ctypes.byref(dacl), None, ctypes.byref(descriptor))
    require(error == 0, "Cannot read access rules: " + str(path) + " error=" + str(error))
    try:
        require(convert(descriptor, 1, 4, ctypes.byref(output), None), "Cannot encode access rules")
        return ctypes.wstring_at(output)
    finally:
        if output.value:
            kernel.LocalFree(output)
        kernel.LocalFree(descriptor)


def access_key(sddl):
    # Unconditional allow entries combine independently of order. Retain exact
    # ordering for deny/object/conditional entries, and retain protection.
    first = sddl.find("(")
    if first < 0:
        return sddl
    prefix, body = sddl[:first], sddl[first:]
    aces = re.findall(r"\([^()]*\)", body)
    if "".join(aces) == body and all(ace.startswith("(A;") for ace in aces):
        return "P" in prefix, tuple(sorted(aces))
    return sddl


def require(condition, message):
    if not condition:
        raise ValueError(message)


def write_new(path, value):
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


def ordinary_root(path):
    path = Path(os.path.abspath(path))
    info = path.lstat()
    require(stat.S_ISDIR(info.st_mode) and not getattr(info, "st_file_attributes", 0) & REPARSE,
            "Expected an ordinary directory: " + str(path))
    return path


def entries(root):
    """Yield directory entries without descending through any reparse point."""
    root = ordinary_root(root)
    stack = [root]
    while stack:
        directory = stack.pop()
        with os.scandir(directory) as iterator:
            for entry in iterator:
                info = entry.stat(follow_symlinks=False)
                relative = Path(entry.path).relative_to(root).as_posix()
                attributes = getattr(info, "st_file_attributes", 0)
                if attributes & REPARSE:
                    require(info.st_reparse_tag in [JUNCTION, SYMLINK], "Unsupported reparse point: " + relative)
                    yield relative, "link", info.st_reparse_tag, 0, os.readlink(entry.path)
                elif entry.is_dir(follow_symlinks=False):
                    yield relative, "directory", 0, 0, None
                    stack.append(Path(entry.path))
                else:
                    require(entry.is_file(follow_symlinks=False), "Unsupported entry: " + relative)
                    yield relative, "file", info.st_size, info.st_mtime_ns, None


def inventory(source, database, summary):
    source = ordinary_root(source)
    # Exclusive creation prevents accidentally replacing an earlier manifest.
    database.open("x").close()
    counts = dict(file=0, directory=0, link=0)
    total = 0
    links = []
    started = last = time.monotonic()
    with sqlite3.connect(database) as connection:
        connection.execute("CREATE TABLE entries(path TEXT PRIMARY KEY, kind TEXT, size INTEGER, mtime_ns INTEGER, link_target TEXT, sha256 TEXT, source_acl_sddl TEXT)")
        connection.execute("CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT)")
        connection.execute("INSERT INTO metadata VALUES('source', ?)", (str(source),))
        for row in entries(source):
            connection.execute("INSERT INTO entries VALUES(?,?,?,?,?,NULL,NULL)", row)
            counts[row[1]] += 1
            if row[1] == "file":
                total += row[2]
            if row[1] == "link":
                links.append(dict(path=row[0], reparse_tag=row[2], target=row[4]))
            if time.monotonic() - last >= 15:
                connection.commit()
                print(json.dumps(dict(stage="inventory", counts=counts, logical_bytes=total)), flush=True)
                last = time.monotonic()
    result = dict(ok=True, source=str(source), counts=counts, logical_bytes=total,
                  links=links, wall_s=time.monotonic()-started)
    write_new(summary, result)
    print(json.dumps({k: v for k, v in result.items() if k != "links"}), flush=True)
    return result


def check_tree(root, expected):
    """Refuse additions, omissions, changed file metadata and crossed links."""
    unseen = set(expected)
    last = time.monotonic()
    for row in entries(root):
        require(row[0] in unseen, "Extra or duplicate path: " + row[0])
        require(tuple(row[1:]) == tuple(expected[row[0]]), "Tree entry changed: " + row[0])
        unseen.remove(row[0])
        if time.monotonic()-last >= 15:
            print(json.dumps(dict(stage="metadata", root=str(root),
                entries_checked=len(expected)-len(unseen), entries_total=len(expected))), flush=True)
            last = time.monotonic()
    require(not unseen, "Missing paths: " + repr(sorted(unseen)[:10]))


def digest_file(path, expected_size, expected_mtime):
    before = path.lstat()
    require(not getattr(before, "st_file_attributes", 0) & REPARSE
            and stat.S_ISREG(before.st_mode)
            and (before.st_size, before.st_mtime_ns) == (expected_size, expected_mtime),
            "File changed before hashing: " + str(path))
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
        after = os.fstat(stream.fileno())
    require((before.st_size, before.st_mtime_ns, before.st_ino) ==
            (after.st_size, after.st_mtime_ns, after.st_ino), "File changed while hashing: " + str(path))
    return digest


def verify(source, destination, database, receipt):
    source, destination = ordinary_root(source), ordinary_root(destination)
    require(source != destination and not source.is_relative_to(destination)
            and not destination.is_relative_to(source), "Overlapping copy roots")
    started = last = time.monotonic()
    result = dict(ok=False, source=str(source), destination=str(destination), files_hashed=0, bytes_hashed_per_tree=0)
    try:
        with sqlite3.connect(database) as connection:
            # Keep the manifest's active pages in memory instead of repeatedly
            # seeking between archive data and tiny SQLite pages on the HDD.
            # Durability and the complete per-file comparison remain unchanged.
            connection.execute("PRAGMA cache_size=-262144")
            require(connection.execute("SELECT value FROM metadata WHERE key='source'").fetchone() == (str(source),),
                    "Manifest source changed")
            expected = {r[0]: r[1:] for r in connection.execute("SELECT path,kind,size,mtime_ns,link_target FROM entries")}
            check_tree(source, expected)
            check_tree(destination, expected)
            print(json.dumps(dict(stage="trees_matched", entries=len(expected))), flush=True)
            for relative, (kind, size, mtime, _) in sorted(expected.items()):
                if kind != "link":
                    source_acl = access_rules(source/relative)
                    destination_acl = access_rules(destination/relative)
                    require(access_key(source_acl) == access_key(destination_acl), "Access rules differ: " + relative)
                    connection.execute("UPDATE entries SET source_acl_sddl=? WHERE path=?", (source_acl, relative))
                if kind != "file":
                    continue
                left = digest_file(source/relative, size, mtime)
                right = digest_file(destination/relative, size, mtime)
                require(left == right, "File content mismatch: " + relative)
                connection.execute("UPDATE entries SET sha256=? WHERE path=?", (left, relative))
                result["files_hashed"] += 1
                result["bytes_hashed_per_tree"] += size
                if time.monotonic() - last >= 15:
                    connection.commit()
                    print(json.dumps(dict(stage="hashing", **result, elapsed_s=time.monotonic()-started)), flush=True)
                    last = time.monotonic()
            check_tree(source, expected)
            check_tree(destination, expected)
            require(connection.execute("SELECT count(*) FROM entries WHERE kind='file' AND sha256 IS NULL").fetchone() == (0,),
                    "Incomplete hash population")
        result["ok"] = True
    except BaseException as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"
        raise
    finally:
        result["wall_s"] = time.monotonic()-started
        with database.open("rb") as stream:
            result["manifest_sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
        write_new(receipt, result)
        print(json.dumps(result), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["inventory", "verify", "check"])
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--destination", type=Path)
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.stage == "inventory":
        inventory(args.source, args.database, args.output)
    elif args.stage == "verify":
        verify(args.source, args.destination, args.database, args.output)
    else:
        with sqlite3.connect(args.database) as connection:
            expected = {r[0]: r[1:] for r in connection.execute("SELECT path,kind,size,mtime_ns,link_target FROM entries")}
        check_tree(args.source, expected)
        if args.destination is not None:
            check_tree(args.destination, expected)
        print(json.dumps(dict(ok=True, stage="metadata_recheck", entries=len(expected))), flush=True)


if __name__ == "__main__":
    main()
