"""Native filesystem controls for a copy that precedes evidence relocation."""
import json
import os
from pathlib import Path
import subprocess
import unittest
import uuid

import verify_evidence_copy as storage
import repair_evidence_permissions as permissions


ROOT = Path(__file__).resolve().parents[2]


class StorageControls(unittest.TestCase):
    def setUp(self):
        self.root = Path(os.environ["STORAGE_TEST_OUTPUT"])/uuid.uuid4().hex
        self.root.mkdir()
        self.source, self.destination = self.root/"source", self.root/"destination"
        self.source.mkdir()
        (self.source/"nested").mkdir()
        (self.source/"first.bin").write_bytes(b"evidence\x00\x01")
        (self.source/"nested/second.txt").write_bytes(b"retained exact bytes\n")
        self.outside = self.root/"outside"
        self.outside.mkdir()
        (self.outside/"sentinel.txt").write_bytes(b"outside evidence; preserve me")
        self.link = self.source/"stored-junction"
        self.make_link(self.link, self.outside)
        self.protect_root(self.source)
        self.database = self.root/"manifest.sqlite"
        self.summary = storage.inventory(self.source, self.database, self.root/"inventory.json")

    def make_link(self, path, target):
        # PowerShell arguments stay positional; no interpolated shell command.
        script = self.root/("junction-"+uuid.uuid4().hex+".ps1")
        script.write_text("param([string]$Path,[string]$Target)\n$ErrorActionPreference='Stop'\nNew-Item -ItemType Junction -Path $Path -Target $Target | Out-Null\n", encoding="utf-8", newline="\n")
        subprocess.run(["pwsh.exe", "-NoProfile", "-File", str(script), str(path), str(target)], cwd=ROOT, check=True, capture_output=True)

    def copy(self):
        self.destination.mkdir()
        self.protect_root(self.destination)
        completed = subprocess.run(["robocopy.exe", str(self.source), str(self.destination),
            "/E", "/COPY:DAT", "/DCOPY:DAT", "/SJ", "/SL", "/R:1", "/W:1", "/NP", "/NFL", "/NDL"], cwd=ROOT, capture_output=True)
        (self.root/"robocopy.stdout").write_bytes(completed.stdout)
        (self.root/"robocopy.stderr").write_bytes(completed.stderr)
        self.assertLess(completed.returncode, 8)

    def protect_root(self, path):
        script = self.root/("permissions-"+uuid.uuid4().hex+".ps1")
        script.write_text("param([string]$Path,[string]$Reference)\n$ErrorActionPreference='Stop'\n$acl=Get-Acl -LiteralPath $Reference\n$acl.SetAccessRuleProtection($true,$true)\nSet-Acl -LiteralPath $Path -AclObject $acl\n", encoding="utf-8", newline="\n")
        subprocess.run(["pwsh.exe", "-NoProfile", "-File", str(script), str(path),
            str(ROOT.parent/"SporeSpore_Evidence")], cwd=ROOT, check=True, capture_output=True)

    def verify(self, name="verification.json"):
        return storage.verify(self.source, self.destination, self.database, self.root/name)

    def test_complete_copy_hashes_every_file_and_preserves_junction(self):
        self.copy()
        result = self.verify()
        self.assertTrue(result["ok"])
        self.assertEqual(result["files_hashed"], 2)
        self.assertEqual(self.summary["counts"], dict(file=2, directory=1, link=1))
        self.assertEqual(os.readlink(self.destination/"stored-junction"), os.readlink(self.link))
        self.assertEqual((self.outside/"sentinel.txt").read_bytes(), b"outside evidence; preserve me")

    def test_same_size_same_time_corruption_is_rejected_by_hash(self):
        self.copy()
        path = self.destination/"first.bin"
        info = path.stat()
        path.write_bytes(b"X"*info.st_size)
        os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
        with self.assertRaisesRegex(ValueError, "File content mismatch"):
            self.verify()
        self.assertFalse(json.loads((self.root/"verification.json").read_text())["ok"])

    def test_source_drift_after_inventory_refuses(self):
        self.copy()
        (self.source/"first.bin").write_bytes(b"changed source")
        with self.assertRaisesRegex(ValueError, "Tree entry changed"):
            self.verify()

    def test_extra_and_missing_destination_paths_refuse(self):
        self.copy()
        extra = self.destination/"unexpected.txt"
        extra.write_bytes(b"unexpected")
        with self.assertRaisesRegex(ValueError, "Extra or duplicate"):
            self.verify("extra.json")
        extra.unlink()
        (self.destination/"nested/second.txt").unlink()
        with self.assertRaisesRegex(ValueError, "Missing paths"):
            self.verify("missing.json")

    def test_crossed_junction_target_refuses(self):
        self.copy()
        link = self.destination/"stored-junction"
        os.rmdir(link)
        other = self.root/"other"
        other.mkdir()
        self.make_link(link, other)
        with self.assertRaisesRegex(ValueError, "Tree entry changed"):
            self.verify()

    def test_unlink_only_removes_junction_and_cannot_inventory_link_root(self):
        self.copy()
        link = self.destination/"stored-junction"
        with self.assertRaisesRegex(ValueError, "ordinary directory"):
            list(storage.entries(link))
        os.rmdir(link)
        self.assertFalse(link.exists())
        self.assertEqual((self.outside/"sentinel.txt").read_bytes(), b"outside evidence; preserve me")

    def test_native_switch_and_cleanup_preserve_destination_and_external_targets(self):
        self.copy()
        self.verify()
        backup = self.root/"original-backup"
        script = self.root/"switch-and-remove.ps1"
        script.write_text("""param([string]$Source,[string]$Destination,[string]$Backup)
$ErrorActionPreference='Stop'
foreach($path in @($Source,$Destination)) {
    $item=Get-Item -LiteralPath $path
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Expected ordinary root' }
}
if ((Split-Path -Parent $Source) -ne (Split-Path -Parent $Backup) -or (Test-Path -LiteralPath $Backup)) { throw 'Unsafe backup path' }
Rename-Item -LiteralPath $Source -NewName (Split-Path -Leaf $Backup)
New-Item -ItemType Junction -Path $Source -Target $Destination | Out-Null
$link=Join-Path $Backup 'stored-junction'
if ((Get-Item -LiteralPath $link).LinkType -ne 'Junction') { throw 'Expected stored junction' }
Remove-Item -LiteralPath $link -Force
if ((Get-Item -LiteralPath $Backup).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked deletion target' }
Remove-Item -LiteralPath $Backup -Recurse -Force
""", encoding="utf-8", newline="\n")
        completed = subprocess.run(["pwsh.exe", "-NoProfile", "-File", str(script),
            str(self.source), str(self.destination), str(backup)], cwd=ROOT, capture_output=True)
        (self.root/"switch.stdout").write_bytes(completed.stdout)
        (self.root/"switch.stderr").write_bytes(completed.stderr)
        self.assertEqual(completed.returncode, 0, completed.stderr.decode(errors="replace"))
        self.assertFalse(backup.exists())
        self.assertEqual(self.source.resolve(), self.destination.resolve())
        self.assertEqual((self.source/"first.bin").read_bytes(), b"evidence\x00\x01")
        self.assertEqual((self.destination/"nested/second.txt").read_bytes(), b"retained exact bytes\n")
        self.assertEqual(os.readlink(self.destination/"stored-junction"), os.readlink(self.link))
        self.assertEqual((self.outside/"sentinel.txt").read_bytes(), b"outside evidence; preserve me")

    def test_native_failed_switch_restores_original(self):
        backup = self.root/"original-backup"
        script = self.root/"failed-switch.ps1"
        script.write_text("""param([string]$Source,[string]$Backup)
$ErrorActionPreference='Stop'
if ((Get-Item -LiteralPath $Source).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Expected ordinary source' }
if ((Split-Path -Parent $Source) -ne (Split-Path -Parent $Backup) -or (Test-Path -LiteralPath $Backup)) { throw 'Unsafe backup path' }
Rename-Item -LiteralPath $Source -NewName (Split-Path -Leaf $Backup)
try { throw 'Injected junction construction failure' }
catch { Rename-Item -LiteralPath $Backup -NewName (Split-Path -Leaf $Source) }
""", encoding="utf-8", newline="\n")
        subprocess.run(["pwsh.exe", "-NoProfile", "-File", str(script),
            str(self.source), str(backup)], cwd=ROOT, check=True, capture_output=True)
        self.assertFalse(backup.exists())
        self.assertEqual(storage.ordinary_root(self.source), self.source)
        self.assertEqual((self.source/"first.bin").read_bytes(), b"evidence\x00\x01")
        self.assertEqual((self.outside/"sentinel.txt").read_bytes(), b"outside evidence; preserve me")

    def test_historical_acl_repair_does_not_propagate_or_change_data(self):
        nested = self.source/"nested"
        source_child = nested/"second.txt"
        child_acl = storage.access_rules(source_child)
        target_acl = storage.access_rules(self.outside/"sentinel.txt")
        # The additional read rule applies only to disposable fixture content.
        custom = storage.access_rules(nested)+"(A;OICIID;FR;;;WD)"
        permissions.set_access_rules(nested, custom, self.source)
        source_acl = storage.access_rules(nested)
        self.assertEqual(storage.access_key(custom), storage.access_key(source_acl))
        self.assertEqual(storage.access_rules(source_child), child_acl)
        self.copy()
        with self.assertRaisesRegex(ValueError,"Access rules differ"):
            self.verify("before-repair.json")
        result = permissions.repair(self.source,self.destination,self.database,self.root/"permissions")
        self.assertTrue(result["ok"])
        self.assertEqual(result["entries_repaired"],1)
        self.assertEqual(result["ordinary_entries_checked"],3)
        self.assertEqual(storage.access_rules(nested),source_acl)
        self.assertEqual(storage.access_rules(self.destination/"nested/second.txt"),child_acl)
        self.assertEqual(storage.access_rules(self.outside/"sentinel.txt"),target_acl)
        self.assertTrue(self.verify("after-repair.json")["ok"])

    def test_permission_setter_rejects_junctions_and_crossed_roots(self):
        self.copy()
        before = storage.access_rules(self.outside/"sentinel.txt")
        for path in [self.destination/"stored-junction", self.destination/"stored-junction/sentinel.txt"]:
            with self.assertRaisesRegex(ValueError,"Linked permission target"):
                permissions.set_access_rules(path,before,self.destination)
        with self.assertRaisesRegex(ValueError,"escaped root"):
            permissions.set_access_rules(self.outside/"sentinel.txt",before,self.destination)
        self.assertEqual(storage.access_rules(self.outside/"sentinel.txt"),before)

    def test_protected_file_acl_is_restored_exactly(self):
        file = self.source/"first.bin"
        original = storage.access_rules(file)
        permissions.set_access_rules(file,"D:P"+original[original.index("("):],self.source)
        protected = storage.access_rules(file)
        self.assertTrue(storage.access_key(protected)[0])
        self.copy()
        result = permissions.repair(self.source,self.destination,self.database,self.root/"permissions")
        self.assertTrue(result["ok"])
        self.assertEqual(result["entries_repaired"],1)
        self.assertEqual(storage.access_key(protected),storage.access_key(storage.access_rules(self.destination/"first.bin")))
        self.assertTrue(self.verify()["ok"])

    def test_permission_batches_retain_before_records_and_complete_tail(self):
        for index in range(101):
            path=self.source/"nested"/(str(index)+".bin")
            path.write_bytes(b"retained fixture data")
            permissions.set_access_rules(path,storage.access_rules(path)+"(A;ID;FR;;;WD)",self.source)
        self.database=self.root/"batch-manifest.sqlite"
        storage.inventory(self.source,self.database,self.root/"batch-inventory.json")
        self.copy()
        result=permissions.repair(self.source,self.destination,self.database,self.root/"permissions")
        self.assertTrue(result["ok"])
        self.assertEqual(result["entries_repaired"],101)
        events=[json.loads(line)["event"] for line in (self.root/"permissions/changes.jsonl").read_text().splitlines()]
        self.assertEqual(events,["before"]*100+["after"]*100+["before","after"])
        self.assertEqual(self.verify()["files_hashed"],103)


if __name__ == "__main__":
    unittest.main()
