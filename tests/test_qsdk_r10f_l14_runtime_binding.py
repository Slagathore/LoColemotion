"""Runtime identity checks read files only; no image is replaced or executed."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l14_runtime_binding as runtime

CONSOLE = Path(runtime.IMAGES["godot_console"]["path"])


class RuntimeBinding(unittest.TestCase):
    def test_actual_native_pair_adapter_and_host_images_are_reopened(self):
        with mock.patch.object(
            runtime, "file_identity", wraps=runtime.file_identity
        ) as reader:
            result = runtime.bind_runtime(CONSOLE)
        self.assertEqual(reader.call_count, 6)  # Foundation plus five actual images.
        runtime.validate_binding(result)
        self.assertEqual(result["images"], runtime.IMAGES)
        self.assertEqual(result["image_count"], 5)
        self.assertNotEqual(
            result["images"]["godot_console"], result["images"]["godot_engine"]
        )
        for name in runtime.ZERO_COUNTERS:
            self.assertIs(type(result[name]), int)
            self.assertEqual(result[name], 0)
        for name in runtime.DENIED_FLAGS:
            self.assertIs(result[name], False)

    def test_wrong_existing_paths_fail_before_any_runtime_image_read(self):
        for options in (
            {"godot": Path(runtime.IMAGES["godot_engine"]["path"])},
            {"godot": CONSOLE, "python_executable": CONSOLE},
            {"godot": CONSOLE, "powershell_executable": CONSOLE},
        ):
            with self.subTest(options=options), mock.patch.object(
                runtime, "file_identity"
            ) as reader:
                with self.assertRaisesRegex(ValueError, "L14_RUNTIME_SELECTED_PATH"):
                    runtime.bind_runtime(**options)
                reader.assert_not_called()
        with mock.patch.object(runtime.sys, "executable", str(CONSOLE)):
            with self.assertRaisesRegex(
                ValueError, "L14_RUNTIME_EXECUTING_PYTHON_PATH"
            ):
                runtime.bind_runtime(
                    CONSOLE,
                    python_executable=Path(runtime.IMAGES["python_helper"]["path"]),
                )
        with mock.patch.object(runtime.shutil, "which", return_value=None):
            with self.assertRaisesRegex(
                ValueError, "L14_RUNTIME_POWERSHELL_NOT_RESOLVED"
            ):
                runtime.bind_runtime(CONSOLE)

    def test_every_binding_field_is_required_and_no_extra_field_is_authority(self):
        original = runtime.expected_binding()
        paths = []

        def visit(value, prefix=()):
            if isinstance(value, dict):
                for key, child in value.items():
                    paths.append((*prefix, key))
                    visit(child, (*prefix, key))

        visit(original)
        self.assertGreater(len(paths), 40)
        for path in paths:
            changed = copy.deepcopy(original)
            owner = changed
            for key in path[:-1]:
                owner = owner[key]
            del owner[path[-1]]
            with self.subTest(path=path), self.assertRaisesRegex(
                ValueError, "L14_RUNTIME_BINDING_NOT_EXACT"
            ):
                runtime.validate_binding(changed)
        for owner_path in ((), ("images",), ("qualified_native_foundation",)):
            changed = copy.deepcopy(original)
            owner = changed
            for key in owner_path:
                owner = owner[key]
            owner["invented_permission"] = True
            with self.assertRaises(ValueError):
                runtime.validate_binding(changed)

    def test_counter_number_kinds_image_roles_and_authority_flags_are_exact(self):
        original = runtime.expected_binding()
        for role in original["images"]:
            for key, replacement in (
                ("byte_length", float(original["images"][role]["byte_length"])),
                ("byte_length", True),
                ("raw_sha256", "sha256:" + "0" * 64),
                ("path", original["images"][role]["path"] + ".other"),
            ):
                changed = copy.deepcopy(original)
                changed["images"][role][key] = replacement
                with self.subTest(role=role, key=key), self.assertRaises(ValueError):
                    runtime.validate_binding(changed)
        for key in (*runtime.ZERO_COUNTERS, "image_count"):
            for replacement in (False, float(original[key]), str(original[key]), None):
                changed = copy.deepcopy(original)
                changed[key] = replacement
                with self.assertRaises(ValueError):
                    runtime.validate_binding(changed)
        for key in (
            *runtime.DENIED_FLAGS,
            "sdk1_m07_satisfied",
            "historical_result_reclassified",
        ):
            changed = copy.deepcopy(original)
            changed[key] = True
            with self.assertRaises(ValueError):
                runtime.validate_binding(changed)

    def test_stored_green_record_cannot_hide_a_changed_or_missing_actual_image(self):
        actual_reader = runtime.file_identity
        for role, image in runtime.IMAGES.items():
            for missing in (False, True):

                def changed_reader(path, **kwargs):
                    if path == Path(image["path"]):
                        if missing:
                            raise FileNotFoundError(
                                "declared_missing_image_fixture:" + role
                            )
                        result = actual_reader(path, **kwargs)
                        result["raw_sha256"] = "sha256:" + "0" * 64
                        return result
                    return actual_reader(path, **kwargs)

                with self.subTest(role=role, missing=missing), mock.patch.object(
                    runtime, "file_identity", side_effect=changed_reader
                ):
                    with self.assertRaises((ValueError, FileNotFoundError)):
                        runtime.verify_qualified_binding(
                            runtime.expected_binding(), CONSOLE
                        )

    def test_native_foundation_identity_and_pair_are_not_inferred_from_current_files(
        self,
    ):
        actual_reader = runtime.file_identity

        def changed_reader(path, **kwargs):
            result = actual_reader(path, **kwargs)
            if path == ROOT / runtime.FOUNDATION["path"]:
                result["raw_sha256"] = "sha256:" + "0" * 64
            return result

        with mock.patch.object(runtime, "file_identity", side_effect=changed_reader):
            with self.assertRaisesRegex(ValueError, "L14_RUNTIME_FOUNDATION_IDENTITY"):
                runtime.bind_runtime(CONSOLE)
        actual_read_text = Path.read_text

        def changed_foundation(path, *args, **kwargs):
            text = actual_read_text(path, *args, **kwargs)
            if path == ROOT / runtime.FOUNDATION["path"]:
                value = json.loads(text)
                value["qualification_receipt"]["exact_runtime"][
                    "binary_pair_complete"
                ] = False
                return json.dumps(value)
            return text

        with mock.patch.object(Path, "read_text", changed_foundation):
            with self.assertRaisesRegex(ValueError, "L14_RUNTIME_FOUNDATION_PAIR"):
                runtime.bind_runtime(CONSOLE)

    def test_actual_cli_binds_and_reopens_an_offered_record_without_any_world(self):
        arguments = [
            sys.executable,
            "-B",
            str(ROOT / "sdk/conformance/qsdk_r10f_l14_runtime_binding.py"),
            "--godot",
            str(CONSOLE),
            "--powershell-host",
            runtime.IMAGES["powershell_host"]["path"],
        ]
        for supplied in (None, runtime.expected_binding()):
            run = subprocess.run(
                arguments + ([] if supplied is None else ["--expected-binding-stdin"]),
                input=None if supplied is None else json.dumps(supplied),
                cwd=ROOT,
                capture_output=True,
                text=True,
                encoding="utf-8",
                timeout=30,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(run.stderr, "")
            lines = run.stdout.splitlines()
            self.assertEqual(len(lines), 1)
            self.assertTrue(lines[0].startswith(runtime.MARKER))
            runtime.validate_binding(json.loads(lines[0][len(runtime.MARKER) :]))
        supplied = runtime.expected_binding()
        supplied["physical_execution_authorized"] = True
        run = subprocess.run(
            arguments + ["--expected-binding-stdin"],
            input=json.dumps(supplied),
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )
        self.assertEqual(run.returncode, 1)
        self.assertNotIn(runtime.MARKER, run.stdout)
        self.assertIn("L14_RUNTIME_BINDING_NOT_EXACT", run.stderr)

    def test_actual_shared_powershell_binder_and_strict_record_consumer(self):
        original = runtime.expected_binding()
        cases = []

        def visit(value, path=()):
            if isinstance(value, dict):
                for key, child in value.items():
                    changed = copy.deepcopy(original)
                    owner = changed
                    for parent in path:
                        owner = owner[parent]
                    del owner[key]
                    cases.append(changed)
                    visit(child, (*path, key))

        visit(original)
        for role in original["images"]:
            for key, value in (
                ("byte_length", float(original["images"][role]["byte_length"])),
                ("raw_sha256", "sha256:" + "0" * 64),
                ("path", str(CONSOLE)),
            ):
                if value == original["images"][role][key] and type(value) is type(
                    original["images"][role][key]
                ):
                    continue
                changed = copy.deepcopy(original)
                changed["images"][role][key] = value
                cases.append(changed)
        changed = copy.deepcopy(original)
        changed["physical_execution_authorized"] = True
        cases.append(changed)
        script = r"""
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. ./sdk/qsdk_r10f_l14_runtime_binding.ps1
$fixtures = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100
Assert-QsdkR10fL14RuntimeBinding $fixtures.expected
$bound = Get-QsdkR10fL14RuntimeBinding -Godot $fixtures.expected.images.godot_console.path
$reopened = Get-QsdkR10fL14RuntimeBinding -Godot $fixtures.expected.images.godot_console.path -ExpectedBinding $bound
if (-not (Test-QsdkR10fL14RuntimeValue $bound $reopened)) { throw "RUNTIME_REOPENED_DRIFT" }
$rejected = 0
foreach ($case in $fixtures.cases) {
    $refused = $false
    try { Assert-QsdkR10fL14RuntimeBinding $case }
    catch {
        if ($_.Exception.Message -cne "L14_RUNTIME_BINDING_NOT_EXACT") { throw }
        $refused = $true
    }
    if (-not $refused) { throw "RUNTIME_RECORD_CORRUPTION_ACCEPTED" }
    $rejected++
}
foreach ($case in @(
    @{ expected = $null; godot = $fixtures.expected.images.godot_console.path; code = "L14_RUNTIME_BINDING_NOT_EXACT" },
    @{ expected = $fixtures.expected; godot = $fixtures.expected.images.godot_engine.path; code = "L14_RUNTIME_SELECTED_PATH:godot_console" }
)) {
    $refused = $false
    try { $null = Get-QsdkR10fL14RuntimeBinding -Godot $case.godot -ExpectedBinding $case.expected }
    catch {
        if ($_.Exception.Message -cne $case.code) { throw }
        $refused = $true
    }
    if (-not $refused) { throw "RUNTIME_BINDING_CALL_CORRUPTION_ACCEPTED" }
    $rejected++
}
@{ binding = $reopened; positive_count = 3; corruption_count = $rejected } | ConvertTo-Json -Depth 100 -Compress
"""
        run = subprocess.run(
            ["pwsh", "-NoProfile", "-Command", script],
            input=json.dumps({"expected": original, "cases": cases}),
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=60,
        )
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stderr, "")
        proof = json.loads(run.stdout)
        runtime.validate_binding(proof["binding"])
        self.assertEqual(proof["positive_count"], 3)
        self.assertEqual(proof["corruption_count"], len(cases) + 2)
        self.assertGreater(proof["corruption_count"], 60)

    def test_qualification_copies_require_all_records_and_reopen_current_images(self):
        binding = runtime.expected_binding()
        retained = {"l14_exact_runtime_images": binding, "synthetic_test_only": True}
        documents = [
            {"l14_exact_runtime_images": copy.deepcopy(binding)},
            {"runtime_identity": copy.deepcopy(retained)},
            {"l14_exact_runtime_images": copy.deepcopy(binding)},
            copy.deepcopy(retained),
        ]
        with mock.patch.object(
            runtime, "bind_runtime", wraps=runtime.bind_runtime
        ) as bind:
            runtime.validate_binding(runtime.qualification_copies(*documents))
            bind.assert_called_once_with(CONSOLE)
        for index in range(4):
            for corruption in [
                None,
                *[case["binding"] for case in runtime.binding_corruptions()],
            ]:
                changed = copy.deepcopy(documents)
                owner = (
                    changed[index]["runtime_identity"] if index == 1 else changed[index]
                )
                if corruption is None:
                    del owner["l14_exact_runtime_images"]
                else:
                    owner["l14_exact_runtime_images"] = corruption
                with self.subTest(copy=index), mock.patch.object(
                    runtime, "bind_runtime"
                ) as bind:
                    with self.assertRaises(ValueError):
                        runtime.qualification_copies(*changed)
                    bind.assert_not_called()
        with mock.patch.object(
            runtime, "bind_runtime", side_effect=ValueError("changed image")
        ):
            with self.assertRaisesRegex(ValueError, "changed image"):
                runtime.qualification_copies(*documents)

    def test_retained_runtime_reopens_exact_json_without_reexecuting_images(self):
        source = "1" * 40
        path = (
            ROOT.parent
            / "SporeSpore_Evidence"
            / (
                "qsdk-r10f-development-route-ghost-zero-world-qualification-"
                + source[:12]
            )
            / "runtime_identity.json"
        )
        binding = {
            "path": path.as_posix(),
            "byte_length": 123,
            "raw_sha256": "sha256:" + "2" * 64,
        }
        document = {
            "l14_exact_runtime_images": runtime.expected_binding(),
            "synthetic_test_only": True,
        }
        # This prospective record does not exist. Only the file reads are
        # synthetic; the actual path/identity/value consumer is executed.
        with mock.patch.object(
            runtime, "file_identity", return_value=binding
        ) as reader, mock.patch.object(
            Path, "read_text", return_value=json.dumps(document)
        ) as text_reader, mock.patch.object(
            runtime, "bind_runtime"
        ) as current:
            self.assertEqual(runtime.read_retained_runtime(binding, source), document)
            reader.assert_called_once_with(path, display_path=path.as_posix())
            text_reader.assert_called_once()
            current.assert_not_called()
        for key, value in (
            ("byte_length", 123.0),
            ("raw_sha256", "sha256:" + "3" * 64),
            ("path", "C:/synthetic/other.json"),
            ("extra", True),
        ):
            changed = {**binding, key: value}
            with mock.patch.object(
                runtime, "file_identity", return_value=binding
            ), mock.patch.object(Path, "read_text") as text_reader:
                with self.assertRaises(ValueError):
                    runtime.read_retained_runtime(changed, source)
                text_reader.assert_not_called()
        with mock.patch.object(
            runtime, "file_identity", return_value=binding
        ), mock.patch.object(
            Path, "read_text", return_value='{"l14_exact_runtime_images":null}'
        ):
            with self.assertRaisesRegex(ValueError, "L14_RUNTIME_BINDING_NOT_EXACT"):
                runtime.read_retained_runtime(binding, source)

    def test_actual_production_runtime_guards_refuse_before_identity_and_each_child(
        self,
    ):
        import inspect
        import qsdk_r10f_authority_materializer as materializer
        import qsdk_r10f_physical_closure as closer
        import qsdk_r10f_zero_world_implementation as implementation

        self.assertIn(
            "l14_runtime.qualification_copies(",
            inspect.getsource(materializer.validate_qualification),
        )
        self.assertIn(
            "l14_runtime.read_retained_runtime(",
            inspect.getsource(closer.validate_l9_authority_files),
        )
        identity_source = inspect.getsource(implementation.runtime_identity)
        self.assertLess(
            identity_source.index("l14_runtime.bind_runtime("),
            identity_source.index("checked_process("),
        )
        audit_source = inspect.getsource(implementation.audit)
        self.assertEqual(audit_source.count("runtime_identity(godot)"), 2)
        self.assertIn("L14_RUNTIME_DRIFT_DURING_QUALIFICATION", audit_source)
        script = r"""
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$fixture = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100
$tokens = $null; $errors = $null
$supervisor = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $fixture.root 'sdk/run_qsdk_r10f_continuous_passive_recovery.ps1'), [ref]$tokens, [ref]$errors)
if (@($errors).Count) { throw "SUPERVISOR_PARSE" }
foreach ($name in @('Assert-R10f', 'Invoke-Physical', 'Invoke-L9ChildProcess')) {
    $nodes = @($supervisor.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $true))
    if ($nodes.Count -ne 1) { throw "FUNCTION_COUNT:$name" }
    . ([scriptblock]::Create($nodes[0].Extent.Text))
}
# The detached host must initialize the same source selector as the real script.
# This is setup only; the production guard and write/start sentinels stay intact.
$repairAssignments = @($supervisor.EndBlock.Statements | Where-Object {
    $_ -is [Management.Automation.Language.AssignmentStatementAst] -and
    $_.Left.Extent.Text -ceq '$script:RepairId'
})
if ($repairAssignments.Count -ne 1) { throw "REPAIR_SOURCE_ASSIGNMENT" }
. ([scriptblock]::Create($repairAssignments[0].Extent.Text))
$wrapper = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $fixture.root 'sdk/qsdk_r10f_zero_world_qualification.ps1'), [ref]$tokens, [ref]$errors)
if (@($errors).Count) { throw "WRAPPER_PARSE" }
$guard = @($wrapper.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -ceq 'Get-QsdkR10fL14RuntimeBinding'
}, $true))
$selection = @($wrapper.FindAll({ param($node)
    $node -is [Management.Automation.Language.IfStatementAst] -and
    $node.Clauses.Count -eq 1 -and $node.Clauses[0].Item1.Extent.Text -ceq '$L15' -and
    $null -ne $node.ElseClause -and $node.Extent.Text.Contains('Get-QsdkR10fL14RuntimeBinding')
}, $true))
if ($guard.Count -ne 2 -or $selection.Count -ne 1) { throw 'QUALIFICATION_RUNTIME_BRANCHES' }
$legacy = $selection[0].ElseClause
$l15 = $selection[0].Clauses[0].Item2
$legacyGuard = @($legacy.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -ceq 'Get-QsdkR10fL14RuntimeBinding'
}, $true))
$creation = @($legacy.FindAll({ param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Extent.Text -ceq '[IO.Directory]::CreateDirectory($qualificationRoot)'
}, $true))
if ($legacyGuard.Count -ne 1 -or $creation.Count -ne 1 -or
    $legacyGuard[0].Extent.StartOffset -ge $creation[0].Extent.StartOffset) { throw "QUALIFICATION_GUARD_ORDER" }
$l15Guard = @($l15.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -ceq 'Get-QsdkR10fL14RuntimeBinding'
}, $true))
$prepare = @($l15.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -ceq 'Invoke-L15QualificationLifecycle' -and
    $node.Extent.Text.Contains('-Phase prepare')
}, $true))
if ($l15Guard.Count -ne 1 -or $prepare.Count -ne 1 -or
    $l15Guard[0].Extent.StartOffset -ge $prepare[0].Extent.StartOffset) { throw 'L15_QUALIFICATION_GUARD_ORDER' }
. (Join-Path $fixture.root 'sdk/qsdk_r10f_l14_runtime_binding.ps1')
$script:guardCalls = 0
function Get-QsdkR10fL14RuntimeBinding {
    param($Godot, $ExpectedBinding, $PythonExecutable)
    if ($Godot -cne $fixture.console) { throw "GUARD_GODOT_ARGUMENT" }
    if ($PSBoundParameters.ContainsKey('ExpectedBinding')) {
        Assert-QsdkR10fL14RuntimeBinding $ExpectedBinding
    } elseif ($PythonExecutable -cne $fixture.python) { throw "GUARD_PYTHON_ARGUMENT" }
    $script:guardCalls++
    throw "SYNTHETIC_CURRENT_IMAGE_DRIFT"
}
# All production writes/process starts are hard failure sentinels. No future
# qualification or physical identity is created by this harness.
function New-Item { throw "UNEXPECTED_WRITE" }
function Write-JsonCreateNew { throw "UNEXPECTED_WRITE" }
function Write-Utf8CreateNew { throw "UNEXPECTED_WRITE" }
function Invoke-SporeSporeGodotReceiptTerminatedProcess { throw "UNEXPECTED_ENGINE_START" }
function Get-SourceBoundary { param([switch]$RequireLiveCleanMain) return @{} }
function Get-PhysicalAuthority { param($Path, $Boundary) return @{ l14_exact_runtime_images = $fixture.binding } }
$RunPhysical = $true
$script:ExpectedEvidenceRoot = [IO.Path]::GetFullPath($fixture.evidence)
$EvidenceRoot = $script:ExpectedEvidenceRoot
$Godot = $fixture.console
$AuthorizationPath = 'synthetic-unread-authority'
$script:GodotPath = $fixture.console
$script:PythonPath = $fixture.python
$script:PhysicalAttemptIdentityConsumed = $false
$refused = 0
foreach ($invoke in @(
    { & ([scriptblock]::Create($guard[0].Extent.Text)) },
    { Invoke-Physical },
    { Invoke-L9ChildProcess -Descriptor @{ role = 'synthetic_baseline' } -Binding @{ l14_exact_runtime_images = $fixture.binding } -GodotPath $fixture.console },
    { Invoke-L9ChildProcess -Descriptor @{ role = 'synthetic_active' } -Binding @{ l14_exact_runtime_images = $fixture.binding } -GodotPath $fixture.console }
)) {
    $failure = $null
    try { & $invoke } catch { $failure = $_.Exception.Message }
    if ($failure -cne 'SYNTHETIC_CURRENT_IMAGE_DRIFT') { throw "PRODUCTION_GUARD_REFUSAL:$failure" }
    if ($script:PhysicalAttemptIdentityConsumed) { throw "IDENTITY_CONSUMED" }
    $refused++
}
@{ refusal_count = $refused; guard_call_count = $script:guardCalls; identity_consumed = $false } | ConvertTo-Json -Compress
"""
        run = subprocess.run(
            ["pwsh", "-NoProfile", "-Command", script],
            input=json.dumps(
                {
                    "root": str(ROOT),
                    "evidence": str(ROOT.parent / "SporeSpore_Evidence"),
                    "console": str(CONSOLE),
                    "python": runtime.IMAGES["python_helper"]["path"],
                    "binding": runtime.expected_binding(),
                }
            ),
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=60,
        )
        self.assertEqual(run.returncode, 0, run.stderr[-5000:])
        self.assertEqual(
            json.loads(run.stdout),
            {"refusal_count": 4, "guard_call_count": 4, "identity_consumed": False},
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
