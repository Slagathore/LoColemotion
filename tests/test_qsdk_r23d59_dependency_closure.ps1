#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$toolPath = Join-Path $turningRoot "r23d59_dependency_closure.py"
$contractPath = Join-Path $turningRoot (
    "r23d59_godot_knee_source_finite_decision_implementation_v1.json"
)

function Assert-R23D59Dependency([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D59 dependency: $Message" }
}

foreach ($path in @($toolPath, $contractPath)) {
    Assert-R23D59Dependency (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing dependency authority: $path"
    )
}

$output = @(& $Python $toolPath --repo-root $repoRoot --contract $contractPath 2>&1)
Assert-R23D59Dependency ($LASTEXITCODE -eq 0) (
    "production dependency composition failed: $($output -join ' ')"
)
$prefix = "QSDK_R23D59_DEPENDENCY_INVENTORY "
$markers = @($output | Where-Object {
    ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal)
})
Assert-R23D59Dependency ($markers.Count -eq 1) "production inventory marker changed"
$inventory = $markers[0].Substring($prefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D59Dependency (
    [string]$inventory.schema_version -ceq
        "sporespore_qsdk_r23d59_dependency_inventory_v1" -and
    [string]$inventory.policy_id -ceq
        "r23d59_declared_roots_recursive_local_language_closure_v1" -and
    [bool]$inventory.expected_transitive_path_set_exact -and
    [bool]$inventory.recursive_local_python_import_inventory_complete -and
    [bool]$inventory.recursive_gdscript_preload_and_load_inventory_complete -and
    [bool]$inventory.powershell_static_dot_source_and_subprocess_path_inventory_complete -and
    [bool]$inventory.declaration_bound_source_inventory_complete -and
    [int]$inventory.transitive_path_count -eq @($inventory.ordered_paths).Count -and
    [int]$inventory.transitive_path_count -eq @($inventory.source_receipts).Count -and
    [int]$inventory.world_build_count -eq 0
) "production dependency inventory receipt changed"

$fixtureParent = [IO.Path]::GetFullPath(
    (Join-Path $repoRoot "sdk\target\qsdk-r23d59-dependency-test")
)
$fixturePrefix = $fixtureParent + [IO.Path]::DirectorySeparatorChar
$fixtureRoot = [IO.Path]::GetFullPath(
    (Join-Path $fixtureParent ([Guid]::NewGuid().ToString("N")))
)
Assert-R23D59Dependency (
    $fixtureRoot.StartsWith($fixturePrefix, [StringComparison]::OrdinalIgnoreCase)
) "temporary fixture escaped its dedicated target directory"
[void][IO.Directory]::CreateDirectory($fixtureRoot)
$inventoryPath = Join-Path $fixtureRoot "inventory.json"
$mutatedContractPath = Join-Path $fixtureRoot "mutated-contract.json"
[IO.File]::WriteAllText(
    $inventoryPath,
    ($inventory | ConvertTo-Json -Depth 100 -Compress),
    [Text.UTF8Encoding]::new($false)
)

$pythonProgram = @'
import copy
import json
from pathlib import Path
import sys

repo = Path(sys.argv[1]).resolve()
inventory_path = Path(sys.argv[2]).resolve()
contract_path = Path(sys.argv[3]).resolve()
mutated_contract_path = Path(sys.argv[4]).resolve()
sys.path.insert(0, str(repo / "sdk" / "turning"))
import r23d59_dependency_closure as closure

inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
paths = inventory["ordered_paths"]
receipts = inventory["source_receipts"]
edges = {(edge["from"], edge["to"]) for edge in inventory["ordered_edges"]}

required_edges = {
    (
        "sdk/turning/r23d59_godot_knee_source_finite_decision.py",
        "sdk/turning/r23d58_godot_cap_source_factorial.py",
    ),
    (
        "sdk/turning/r23d58_godot_cap_source_factorial.py",
        "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization.py",
    ),
    (
        "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization.py",
        "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization.py",
    ),
    (
        "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization.py",
        "sdk/turning/r23d54_godot_actuator_phase_characterization.py",
    ),
    (
        "sdk/turning/r23d54_godot_actuator_phase_characterization.py",
        "sdk/turning/r23d53_godot_warmup_preserving_origin_reanchor.py",
    ),
    (
        "tests/test_sdk_qsdk_r23d59_godot_jolt_physical_worker.gd",
        "tests/test_sdk_qsdk_r23d58_godot_jolt_physical_worker.gd",
    ),
    (
        "sdk/run_qsdk_r23d59_supervisor.ps1",
        "sdk/content_addressed_artifact_store.ps1",
    ),
    (
        "sdk/run_qsdk_r23d59_supervisor.ps1",
        "sdk/turning/r23d59_godot_knee_source_finite_decision_evaluator.py",
    ),
}
if not required_edges.issubset(edges):
    raise RuntimeError(f"missing required recursive edges: {sorted(required_edges - edges)}")

path_removal_rejections = 0
for index in range(len(paths)):
    candidate = paths[:index] + paths[index + 1 :]
    try:
        closure.assert_expected_path_set(paths, candidate)
    except closure.DependencyClosureError:
        path_removal_rejections += 1

receipt_removal_rejections = 0
for index in range(len(receipts)):
    candidate = receipts[:index] + receipts[index + 1 :]
    try:
        closure.assert_receipt_closure(paths, candidate)
    except closure.DependencyClosureError:
        receipt_removal_rejections += 1

structural_rejections = 0
mutations = []
duplicate = copy.deepcopy(receipts)
duplicate.append(copy.deepcopy(duplicate[0]))
mutations.append(duplicate)
digest = copy.deepcopy(receipts)
digest[0]["raw_sha256"] = "sha256:" + "g" * 64
mutations.append(digest)
case = copy.deepcopy(receipts)
case[0]["path"] = case[0]["path"].upper()
mutations.append(case)
order = copy.deepcopy(receipts)
order[0], order[1] = order[1], order[0]
mutations.append(order)
for candidate in mutations:
    try:
        closure.assert_receipt_closure(paths, candidate)
    except closure.DependencyClosureError:
        structural_rejections += 1

contract = json.loads(contract_path.read_text(encoding="utf-8"))
contract["dependency_closure"]["expected_inventory_projection_sha256"] = (
    "sha256:" + "0" * 64
)
mutated_contract_path.write_text(
    json.dumps(contract, sort_keys=True, separators=(",", ":")),
    encoding="utf-8",
)
projection_mutation_rejected = False
try:
    closure.compose_inventory(
        repo_root=repo,
        contract_path=mutated_contract_path,
        require_expected_paths=True,
        require_clean_git_bytes=False,
    )
except closure.DependencyClosureError as error:
    projection_mutation_rejected = "PROJECTION_MISMATCH" in str(error)

if (
    path_removal_rejections != len(paths)
    or receipt_removal_rejections != len(receipts)
    or structural_rejections != len(mutations)
    or not projection_mutation_rejected
):
    raise RuntimeError("dependency mutation controls incomplete")

print(
    json.dumps(
        {
            "path_removal_rejections": path_removal_rejections,
            "receipt_removal_rejections": receipt_removal_rejections,
            "structural_rejections": structural_rejections,
            "projection_mutation_rejections": 1,
            "required_recursive_edge_positive_controls": len(required_edges),
        },
        sort_keys=True,
        separators=(",", ":"),
    )
)
'@

try {
    $controlOutput = @(& $Python -c $pythonProgram $repoRoot $inventoryPath `
        $contractPath $mutatedContractPath 2>&1)
    Assert-R23D59Dependency ($LASTEXITCODE -eq 0) (
        "dependency mutation controls failed: $($controlOutput -join ' ')"
    )
    $controls = $controlOutput[-1] | ConvertFrom-Json -AsHashtable
    Assert-R23D59Dependency (
        [int]$controls.path_removal_rejections -eq
            [int]$inventory.transitive_path_count -and
        [int]$controls.receipt_removal_rejections -eq
            [int]$inventory.transitive_path_count -and
        [int]$controls.structural_rejections -eq 4 -and
        [int]$controls.projection_mutation_rejections -eq 1 -and
        [int]$controls.required_recursive_edge_positive_controls -eq 8
    ) "dependency mutation-control receipt changed"
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        $resolvedFixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
        Assert-R23D59Dependency (
            $resolvedFixtureRoot.StartsWith(
                $fixturePrefix,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) "refusing to remove a fixture outside its dedicated target directory"
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Host (
    "QSDK_R23D59_DEPENDENCY_CLOSURE_PASS " +
    "paths=$($inventory.transitive_path_count) edges=$($inventory.edge_count) " +
    "path_removals=$($controls.path_removal_rejections) " +
    "receipt_removals=$($controls.receipt_removal_rejections) " +
    "structural_mutations=$($controls.structural_rejections) " +
    "projection_mutations=$($controls.projection_mutation_rejections) " +
    "recursive_edge_controls=$($controls.required_recursive_edge_positive_controls) " +
    "models=0 worlds=0 physical_authority=False"
)
