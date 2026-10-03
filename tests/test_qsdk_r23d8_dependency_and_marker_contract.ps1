#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$dependencyModule = Join-Path $repoRoot (
    "sdk\turning\r23d8_dependency_closure.ps1"
)
$markerModule = Join-Path $repoRoot (
    "sdk\turning\r23d8_terminal_marker_classifier.ps1"
)
. $dependencyModule
. $markerModule

function Assert-R23D8Contract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-R23D8SyntheticReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Path)
    $digest = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
    return [ordered]@{ path = $Path; raw_sha256 = "sha256:$digest" }
}

function New-R23D8RetentionReceipt {
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d8_process_retention_receipt_v1"
        retained_before_marker_interpretation = $true
        process_raw_sha256 = "sha256:" + ("1" * 64)
        stdout_raw_sha256 = "sha256:" + ("2" * 64)
        stderr_raw_sha256 = "sha256:" + ("3" * 64)
        engine_log_required = $false
        engine_log_raw_sha256 = ""
        all_retained_bytes_content_addressed = $true
    }
}

foreach ($path in @($dependencyModule, $markerModule)) {
    Assert-R23D8Contract (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D8 shared contract module missing: $path"
    )
}
$manifest = Get-R23D8DependencyManifest -RepoRoot $repoRoot
Assert-R23D8Contract (
    [int]$manifest.unique_dependency_count -eq 28 -and
    (@($manifest.ordered_worker_ids) -join "|") -ceq
        "mujoco|rapier_parry|godot_jolt"
) "QSDK-R23D8 composed dependency manifest changed"

$required = @($manifest.union_paths | ForEach-Object {
    New-R23D8SyntheticReceipt ([string]$_)
})
$perfect = Test-R23D8DependencyReceiptClosure `
    -Manifest $manifest `
    -RequiredReceipts $required `
    -SourceBindings $required
Assert-R23D8Contract ([bool]$perfect.ok) (
    "QSDK-R23D8 perfect dependency closure failed"
)

$removalCanaries = 0
foreach ($removed in @($manifest.union_paths)) {
    $candidate = @($required | Where-Object {
        [string]$_.path -cne [string]$removed
    })
    $result = Test-R23D8DependencyReceiptClosure `
        -Manifest $manifest `
        -RequiredReceipts $required `
        -SourceBindings $candidate
    Assert-R23D8Contract (
        -not [bool]$result.ok -and
        [string]$result.failure_code -ceq "R23D8_DEPENDENCY_CLOSURE_INVALID" -and
        @($result.missing_paths) -ccontains [string]$removed
    ) "QSDK-R23D8 removal canary passed unexpectedly: $removed"
    $removalCanaries += 1
}

$duplicate = @($required) + @($required[0])
$duplicateResult = Test-R23D8DependencyReceiptClosure `
    -Manifest $manifest -RequiredReceipts $required -SourceBindings $duplicate
Assert-R23D8Contract (
    -not [bool]$duplicateResult.ok -and
    [string]$duplicateResult.failure_code -ceq
        "R23D8_DEPENDENCY_SOURCE_BINDINGS_INVALID"
) "QSDK-R23D8 duplicate source binding was accepted"

$caseChanged = @($required | ForEach-Object {
    if ([string]$_.path -ceq [string]$required[0].path) {
        [ordered]@{
            path = ([string]$_.path).ToUpperInvariant()
            raw_sha256 = [string]$_.raw_sha256
        }
    } else { $_ }
})
$caseResult = Test-R23D8DependencyReceiptClosure `
    -Manifest $manifest -RequiredReceipts $required -SourceBindings $caseChanged
Assert-R23D8Contract (
    -not [bool]$caseResult.ok -and @($caseResult.missing_paths).Count -eq 1
) "QSDK-R23D8 case-changed dependency was accepted"

$unknownResult = Test-R23D8DependencyReceiptClosure `
    -Manifest $manifest -RequiredReceipts $required -SourceBindings $required `
    -WorkerId "unknown"
Assert-R23D8Contract (
    -not [bool]$unknownResult.ok -and
    [string]$unknownResult.failure_code -ceq "R23D8_DEPENDENCY_UNKNOWN_WORKER"
) "QSDK-R23D8 unknown worker manifest was accepted"

$emptyManifest = [ordered]@{
    ordered_worker_ids = @("mujoco")
    required_paths_by_worker = [ordered]@{ mujoco = @() }
    union_paths = @()
}
$emptyResult = Test-R23D8DependencyReceiptClosure `
    -Manifest $emptyManifest -RequiredReceipts @() -SourceBindings @() `
    -WorkerId "mujoco"
Assert-R23D8Contract (
    -not [bool]$emptyResult.ok -and
    [string]$emptyResult.failure_code -ceq
        "R23D8_DEPENDENCY_EMPTY_REQUIRED_SET"
) "QSDK-R23D8 empty worker manifest was accepted"

$retention = New-R23D8RetentionReceipt
$successEntry = [ordered]@{
    schema_version = "sporespore_qsdk_r23d8_engine_cell_report_v1"
    failure_code = ""
}
$failureEntry = [ordered]@{
    schema_version = "sporespore_qsdk_r23d8_worker_failure_v1"
    failure_code = "R23D8_SYNTHETIC_WORKER_FAILURE"
}
$successJson = $successEntry | ConvertTo-Json -Compress
$failureJson = $failureEntry | ConvertTo-Json -Compress
$families = @(
    "mujoco_single_terminal_prefix",
    "rapier_separate_success_failure_prefixes",
    "godot_jolt_separate_success_failure_prefixes"
)
$caseCount = 0
foreach ($family in $families) {
    $definition = Get-R23D8MarkerFamilyDefinition $family
    if ($family -ceq "mujoco_single_terminal_prefix") {
        $successLine = [string]$definition.single_prefix + $successJson
        $failureLine = [string]$definition.single_prefix + $failureJson
        $malformedLine = [string]$definition.single_prefix + "{"
    } else {
        $successLine = [string]$definition.success_prefix + $successJson
        $failureLine = [string]$definition.failure_prefix + $failureJson
        $malformedLine = [string]$definition.success_prefix + "{"
    }
    $cases = @(
        @{ name = "zero"; stdout = ""; exit = 1; class = "supervisor_process_failure"; code = "R23D8_TERMINAL_MARKER_ZERO" },
        @{ name = "one"; stdout = $successLine; exit = 0; class = "success"; code = "" },
        @{ name = "many"; stdout = "$successLine`n$successLine"; exit = 0; class = "supervisor_process_failure"; code = "R23D8_TERMINAL_MARKER_MANY" },
        @{ name = "mixed"; stdout = "$successLine`n$failureLine"; exit = 1; class = "supervisor_process_failure"; code = "R23D8_TERMINAL_MARKER_MIXED" },
        @{ name = "malformed"; stdout = $malformedLine; exit = 1; class = "supervisor_process_failure"; code = "R23D8_TERMINAL_MARKER_MALFORMED" }
    )
    foreach ($case in $cases) {
        $result = Get-R23D8TerminalMarkerClassification `
            -FamilyId $family `
            -Stdout ([string]$case.stdout) `
            -ExitCode ([int]$case.exit) `
            -RetentionReceipt $retention
        Assert-R23D8Contract (
            [string]$result.classification -ceq [string]$case.class -and
            [string]$result.failure_code -ceq [string]$case.code
        ) "QSDK-R23D8 marker case changed: $family/$($case.name)"
        $caseCount += 1
    }
    $workerFailure = Get-R23D8TerminalMarkerClassification `
        -FamilyId $family -Stdout $failureLine -ExitCode 1 `
        -RetentionReceipt $retention
    Assert-R23D8Contract (
        [string]$workerFailure.classification -ceq "worker_failure" -and
        [string]$workerFailure.failure_code -ceq
            "R23D8_SYNTHETIC_WORKER_FAILURE"
    ) "QSDK-R23D8 valid worker failure changed: $family"
    $badSuccessExit = Get-R23D8TerminalMarkerClassification `
        -FamilyId $family -Stdout $successLine -ExitCode 1 `
        -RetentionReceipt $retention
    $badFailureExit = Get-R23D8TerminalMarkerClassification `
        -FamilyId $family -Stdout $failureLine -ExitCode 0 `
        -RetentionReceipt $retention
    Assert-R23D8Contract (
        [string]$badSuccessExit.failure_code -ceq
            "R23D8_TERMINAL_EXIT_MARKER_MISMATCH" -and
        [string]$badFailureExit.failure_code -ceq
            "R23D8_TERMINAL_EXIT_MARKER_MISMATCH"
    ) "QSDK-R23D8 exit/marker pairing was not fail closed: $family"
}

$retentionRejected = $false
try {
    $badRetention = New-R23D8RetentionReceipt
    $badRetention.retained_before_marker_interpretation = $false
    [void](Get-R23D8TerminalMarkerClassification `
        -FamilyId $families[0] -Stdout "" -ExitCode 1 `
        -RetentionReceipt $badRetention)
} catch {
    $retentionRejected = $_.Exception.Message.Contains(
        "forbidden before complete retention"
    )
}
Assert-R23D8Contract $retentionRejected (
    "QSDK-R23D8 marker classifier accepted pre-retention interpretation"
)

Write-Host (
    "QSDK_R23D8_DEPENDENCY_MARKER_PASS workers=3 dependencies=28 " +
    "removal_canaries=$removalCanaries structural_canaries=4 " +
    "marker_families=3 marker_cases=$caseCount exit_pair_canaries=6 " +
    "retention_canaries=1 worlds=0 physical_authority=False"
)
