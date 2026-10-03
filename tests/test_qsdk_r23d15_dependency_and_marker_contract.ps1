#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$dependencyModule = Join-Path $repoRoot (
    "sdk\turning\r23d15_dependency_closure.ps1"
)
$markerModule = Join-Path $repoRoot (
    "sdk\turning\r23d15_terminal_marker_classifier.ps1"
)
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d15_physical_implementation_contract_v1.json"
)
. $dependencyModule
. $markerModule

function Assert-R23D15Contract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-R23D15SyntheticReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Path)
    $digest = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
    return [ordered]@{ path = $Path; raw_sha256 = "sha256:$digest" }
}

function New-R23D15RetentionReceipt {
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d15_process_retention_receipt_v1"
        retained_before_marker_interpretation = $true
        process_raw_sha256 = "sha256:" + ("1" * 64)
        stdout_raw_sha256 = "sha256:" + ("2" * 64)
        stderr_raw_sha256 = "sha256:" + ("3" * 64)
        engine_log_required = $false
        engine_log_raw_sha256 = ""
        all_retained_bytes_content_addressed = $true
    }
}

foreach ($path in @($dependencyModule, $markerModule, $implementationPath)) {
    Assert-R23D15Contract (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D15 shared contract module missing: $path"
    )
}

$fixtureRoot = Join-Path $repoRoot (
    "sdk\target\qsdk-r23d15-dependency-marker-test\" + [guid]::NewGuid().ToString("N")
)
[void](New-Item -ItemType Directory -Path $fixtureRoot -Force)
$fixturePath = Join-Path $fixtureRoot "implementation-contract.json"
$fixture = [ordered]@{
    schema_version = "sporespore_qsdk_r23d15_physical_implementation_contract_v1"
    dependency_closure = [ordered]@{
        manifest_schema_version = "sporespore_qsdk_r23d15_worker_dependency_manifest_v1"
        declared_worker_ids = @("mujoco", "rapier_parry", "godot_jolt")
        required_dependency_paths_by_worker = [ordered]@{
            mujoco = @(
                "sdk/turning/r23d10_quiescent_taper.py",
                "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_tight_gated_horizon.py"
            )
            rapier_parry = @(
                "sdk/adapters/rapier/src/qsdk_r23d14_tight_gated_horizon.rs",
                "sdk/turning/r23d10_quiescent_taper.py"
            )
            godot_jolt = @(
                "scripts/lab/gait/sdk_godot_jolt_quiescent_taper.gd",
                "sdk/turning/r23d10_quiescent_taper.py"
            )
        }
        declared_unique_dependency_count = 4
    }
}
$fixture | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $fixturePath -Encoding utf8NoBOM

$manifest = Get-R23D15DependencyManifest `
    -RepoRoot $repoRoot -DeclarationPath $fixturePath
Assert-R23D15Contract (
    [int]$manifest.unique_dependency_count -eq 4 -and
    (@($manifest.ordered_worker_ids) -join "|") -ceq
        "mujoco|rapier_parry|godot_jolt"
) "QSDK-R23D15 composed dependency manifest changed"

$required = @($manifest.union_paths | ForEach-Object {
    New-R23D15SyntheticReceipt ([string]$_)
})
$perfect = Test-R23D15DependencyReceiptClosure `
    -Manifest $manifest -RequiredReceipts $required -SourceBindings $required
Assert-R23D15Contract ([bool]$perfect.ok) (
    "QSDK-R23D15 perfect dependency closure failed"
)
$liveReceipts = New-R23D15DependencyReceipts -RepoRoot $repoRoot -Manifest $manifest
Assert-R23D15Contract (
    @($liveReceipts).Count -eq 4 -and
    @($liveReceipts | Where-Object {
        [string]$_.raw_sha256 -cnotmatch '^sha256:[0-9a-f]{64}$'
    }).Count -eq 0
) "QSDK-R23D15 live tracked dependency receipts failed"

$fixtureRemovalCanaries = 0
foreach ($removed in @($manifest.union_paths)) {
    $candidate = @($required | Where-Object {
        [string]$_.path -cne [string]$removed
    })
    $result = Test-R23D15DependencyReceiptClosure `
        -Manifest $manifest -RequiredReceipts $required -SourceBindings $candidate
    Assert-R23D15Contract (
        -not [bool]$result.ok -and
        [string]$result.failure_code -ceq "R23D15_DEPENDENCY_CLOSURE_INVALID" -and
        @($result.missing_paths) -ccontains [string]$removed
    ) "QSDK-R23D15 removal canary passed unexpectedly: $removed"
    $fixtureRemovalCanaries += 1
}

# The compact fixture above exercises the composer and live tracked-byte
# receipt path.  The release-bearing negative control must separately remove
# every dependency from the real production manifest once; four fixture
# removals cannot stand in for the declared 75-path worker union.
$productionManifest = Get-R23D15DependencyManifest `
    -RepoRoot $repoRoot -DeclarationPath $implementationPath
Assert-R23D15Contract (
    [int]$productionManifest.unique_dependency_count -eq 75 -and
    (@($productionManifest.ordered_worker_ids) -join "|") -ceq
        "mujoco|rapier_parry|godot_jolt"
) "QSDK-R23D15 production dependency manifest changed"
$productionRequired = @($productionManifest.union_paths | ForEach-Object {
    New-R23D15SyntheticReceipt ([string]$_)
})
$productionPerfect = Test-R23D15DependencyReceiptClosure `
    -Manifest $productionManifest `
    -RequiredReceipts $productionRequired `
    -SourceBindings $productionRequired
Assert-R23D15Contract ([bool]$productionPerfect.ok) (
    "QSDK-R23D15 perfect production dependency closure failed"
)
$removalCanaries = 0
foreach ($removed in @($productionManifest.union_paths)) {
    $candidate = @($productionRequired | Where-Object {
        [string]$_.path -cne [string]$removed
    })
    $result = Test-R23D15DependencyReceiptClosure `
        -Manifest $productionManifest `
        -RequiredReceipts $productionRequired `
        -SourceBindings $candidate
    Assert-R23D15Contract (
        -not [bool]$result.ok -and
        [string]$result.failure_code -ceq "R23D15_DEPENDENCY_CLOSURE_INVALID" -and
        @($result.missing_paths) -ccontains [string]$removed
    ) "QSDK-R23D15 production removal canary passed unexpectedly: $removed"
    $removalCanaries += 1
}
Assert-R23D15Contract (
    $fixtureRemovalCanaries -eq 4 -and $removalCanaries -eq 75
) "QSDK-R23D15 dependency removal-canary count changed"

$duplicate = @($required) + @($required[0])
$duplicateResult = Test-R23D15DependencyReceiptClosure `
    -Manifest $manifest -RequiredReceipts $required -SourceBindings $duplicate
Assert-R23D15Contract (
    -not [bool]$duplicateResult.ok -and
    [string]$duplicateResult.failure_code -ceq
        "R23D15_DEPENDENCY_SOURCE_BINDINGS_INVALID"
) "QSDK-R23D15 duplicate source binding was accepted"

$caseChanged = @($required | ForEach-Object {
    if ([string]$_.path -ceq [string]$required[0].path) {
        [ordered]@{
            path = ([string]$_.path).ToUpperInvariant()
            raw_sha256 = [string]$_.raw_sha256
        }
    } else { $_ }
})
$caseResult = Test-R23D15DependencyReceiptClosure `
    -Manifest $manifest -RequiredReceipts $required -SourceBindings $caseChanged
Assert-R23D15Contract (
    -not [bool]$caseResult.ok -and @($caseResult.missing_paths).Count -eq 1
) "QSDK-R23D15 case-changed dependency was accepted"

$unknownResult = Test-R23D15DependencyReceiptClosure `
    -Manifest $manifest -RequiredReceipts $required -SourceBindings $required `
    -WorkerId "unknown"
Assert-R23D15Contract (
    -not [bool]$unknownResult.ok -and
    [string]$unknownResult.failure_code -ceq "R23D15_DEPENDENCY_UNKNOWN_WORKER"
) "QSDK-R23D15 unknown worker manifest was accepted"

$emptyManifest = [ordered]@{
    ordered_worker_ids = @("mujoco")
    required_paths_by_worker = [ordered]@{ mujoco = @() }
    union_paths = @()
}
$emptyResult = Test-R23D15DependencyReceiptClosure `
    -Manifest $emptyManifest -RequiredReceipts @() -SourceBindings @() `
    -WorkerId "mujoco"
Assert-R23D15Contract (
    -not [bool]$emptyResult.ok -and
    [string]$emptyResult.failure_code -ceq
        "R23D15_DEPENDENCY_EMPTY_REQUIRED_SET"
) "QSDK-R23D15 empty worker manifest was accepted"

$retention = New-R23D15RetentionReceipt
$successEntry = [ordered]@{
    schema_version = "sporespore_qsdk_r23d15_engine_cell_report_v1"
    failure_code = ""
}
$failureEntry = [ordered]@{
    schema_version = "sporespore_qsdk_r23d15_worker_failure_v1"
    failure_code = "R23D15_SYNTHETIC_WORKER_FAILURE"
}
$successJson = $successEntry | ConvertTo-Json -Compress
$failureJson = $failureEntry | ConvertTo-Json -Compress
$families = @(
    "mujoco_single_terminal_prefix",
    "rapier_single_terminal_prefix",
    "godot_jolt_single_terminal_prefix"
)
$caseCount = 0
foreach ($family in $families) {
    $definition = Get-R23D15MarkerFamilyDefinition $family
    $successLine = [string]$definition.single_prefix + $successJson
    $failureLine = [string]$definition.single_prefix + $failureJson
    $malformedLine = [string]$definition.single_prefix + "{"
    $cases = @(
        @{ name = "zero"; stdout = ""; exit = 1; class = "supervisor_process_failure"; code = "R23D15_TERMINAL_MARKER_ZERO" },
        @{ name = "one"; stdout = $successLine; exit = 0; class = "success"; code = "" },
        @{ name = "many"; stdout = "$successLine`n$successLine"; exit = 0; class = "supervisor_process_failure"; code = "R23D15_TERMINAL_MARKER_MANY" },
        @{ name = "mixed"; stdout = "$successLine`n$failureLine"; exit = 1; class = "supervisor_process_failure"; code = "R23D15_TERMINAL_MARKER_MIXED" },
        @{ name = "malformed"; stdout = $malformedLine; exit = 1; class = "supervisor_process_failure"; code = "R23D15_TERMINAL_MARKER_MALFORMED" }
    )
    foreach ($case in $cases) {
        $result = Get-R23D15TerminalMarkerClassification `
            -FamilyId $family -Stdout ([string]$case.stdout) `
            -ExitCode ([int]$case.exit) -RetentionReceipt $retention
        Assert-R23D15Contract (
            [string]$result.classification -ceq [string]$case.class -and
            [string]$result.failure_code -ceq [string]$case.code
        ) "QSDK-R23D15 marker case changed: $family/$($case.name)"
        $caseCount += 1
    }
    $workerFailure = Get-R23D15TerminalMarkerClassification `
        -FamilyId $family -Stdout $failureLine -ExitCode 1 `
        -RetentionReceipt $retention
    Assert-R23D15Contract (
        [string]$workerFailure.classification -ceq "worker_failure" -and
        [string]$workerFailure.failure_code -ceq
            "R23D15_SYNTHETIC_WORKER_FAILURE"
    ) "QSDK-R23D15 valid worker failure changed: $family"
    $badSuccessExit = Get-R23D15TerminalMarkerClassification `
        -FamilyId $family -Stdout $successLine -ExitCode 1 `
        -RetentionReceipt $retention
    $badFailureExit = Get-R23D15TerminalMarkerClassification `
        -FamilyId $family -Stdout $failureLine -ExitCode 0 `
        -RetentionReceipt $retention
    Assert-R23D15Contract (
        [string]$badSuccessExit.failure_code -ceq
            "R23D15_TERMINAL_EXIT_MARKER_MISMATCH" -and
        [string]$badFailureExit.failure_code -ceq
            "R23D15_TERMINAL_EXIT_MARKER_MISMATCH"
    ) "QSDK-R23D15 exit/marker pairing was not fail closed: $family"
}

$retentionRejected = $false
try {
    $badRetention = New-R23D15RetentionReceipt
    $badRetention.retained_before_marker_interpretation = $false
    [void](Get-R23D15TerminalMarkerClassification `
        -FamilyId $families[0] -Stdout "" -ExitCode 1 `
        -RetentionReceipt $badRetention)
} catch {
    $retentionRejected = $_.Exception.Message.Contains(
        "forbidden before complete retention"
    )
}
Assert-R23D15Contract $retentionRejected (
    "QSDK-R23D15 marker classifier accepted pre-retention interpretation"
)
Write-Host (
    "QSDK_R23D15_DEPENDENCY_MARKER_PASS workers=3 dependencies=75 " +
    "removal_canaries=$removalCanaries fixture_dependencies=4 " +
    "fixture_removal_canaries=$fixtureRemovalCanaries structural_canaries=5 " +
    "marker_families=3 marker_cases=$caseCount exit_pair_canaries=6 " +
    "retention_canaries=1 worlds=0 physical_authority=False"
)
