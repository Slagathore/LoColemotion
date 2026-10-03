#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$contractPath = Join-Path $repoRoot (
    "sdk\turning\r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json"
)
$designPath = Join-Path $repoRoot (
    "sdk\turning\r23d58_godot_cap_source_factorial.py"
)
$evaluatorPath = Join-Path $repoRoot (
    "sdk\turning\r23d58_godot_cap_source_factorial_evaluator.py"
)
$workerPath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d58_godot_jolt_physical_worker.gd"
)
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d58_supervisor.ps1"
$parentClosureAudit = Join-Path $repoRoot "tests\test_qsdk_r23d57_physical_closure.ps1"
$factorialAudit = Join-Path $repoRoot (
    "tests\test_qsdk_r23d58_terminal_trace_cap_factorial_zero_world.ps1"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d58_godot_cap_source_factorial_closure_v1.json"
)
$closureAudit = Join-Path $repoRoot "tests\test_qsdk_r23d58_physical_closure.ps1"

function Assert-R23D58([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D58 LINEAGE: $Message" }
}

function Resolve-R23D58Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D58 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Invoke-R23D58Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $stdoutPath = [IO.Path]::GetTempFileName()
    $stderrPath = [IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath $FileName -ArgumentList $Arguments `
            -WorkingDirectory $repoRoot -NoNewWindow -PassThru -Wait `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        return [ordered]@{
            exit_code = [int]$process.ExitCode
            stdout = [IO.File]::ReadAllText($stdoutPath)
            stderr = [IO.File]::ReadAllText($stderrPath)
        }
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-R23D58MarkerJson([string]$Text, [string]$Prefix) {
    $matches = @(
        $Text -split "`r?`n" | Where-Object {
            $_.StartsWith($Prefix, [StringComparison]::Ordinal)
        }
    )
    Assert-R23D58 ($matches.Count -eq 1) "marker changed: $Prefix"
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$top = (& git -C $repoRoot rev-parse --show-toplevel 2>&1 | Out-String).Trim()
Assert-R23D58 ($LASTEXITCODE -eq 0) "repository root lookup failed"
Assert-R23D58 (
    [IO.Path]::GetFullPath($top).TrimEnd('\', '/') -ceq
        $repoRoot.TrimEnd('\', '/')
) "wrong repository root"
$remote = (& git -C $repoRoot remote get-url origin 2>&1 | Out-String).Trim()
Assert-R23D58 ($LASTEXITCODE -eq 0 -and $remote -ceq $expectedRemote) (
    "wrong origin remote"
)

foreach ($path in @(
    $contractPath,
    $designPath,
    $evaluatorPath,
    $workerPath,
    $supervisorPath,
    $parentClosureAudit,
    $factorialAudit,
    $closurePath,
    $closureAudit
)) {
    Assert-R23D58 (Test-Path -LiteralPath $path -PathType Leaf) (
        "required path is missing: $path"
    )
}
$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$design = $contract.frozen_future_physical_design
$campaign = $contract.prospective_campaign_execution_boundary
Assert-R23D58 (
    [string]$contract.status -ceq
        "prospective_campaign_machinery_implemented_complete_zero_world_gates_passed_physical_campaign_not_opened" -and
    [string]$contract.gate_id -ceq "QSDK-R23D58" -and
    [string]$contract.question_class -ceq "development" -and
    [bool]$contract.physical_question_declared -and
    -not [bool]$contract.physical_campaign_opened -and
    [string]$campaign.campaign_id -ceq
        "QSDK-R23D58-GODOT-CAP-SOURCE-FACTORIAL-REAR-CONTACT-MECHANISM-DEVELOPMENT" -and
    [int]$design.declared_cell_count -eq 4 -and
    [int]$design.declared_world_count -eq 4 -and
    @($design.ordered_profile_ids).Count -eq 4 -and
    [bool]$design.serial_execution_required -and
    [bool]$design.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$design.fresh_world_required_per_cell -and
    [bool]$design.profile_bound_once_before_first_authoritative_controller_step -and
    -not [bool]$design.turning_evaluator_invoked -and
    -not [bool]$design.mechanism_selection_rule_declared -and
    -not [bool]$design.physical_execution_authorized -and
    -not [bool]$campaign.physical_execution_authorized
) "campaign declaration changed"
Assert-R23D58 (
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_outcome_exposed_godot_cap_source_factorial_rear_contact_mechanism_development" -and
    [string]$closure.campaign_id -ceq [string]$campaign.campaign_id -and
    [string]$closure.source_commit -ceq
        "ecfc191bcc97ea53b089e9862a5d0b5a7a8ad6b5" -and
    [string]$closure.attempt_id -ceq
        "5d29697174f04d6c9d5a89dda2288165" -and
    [bool]$closure.identity_consumed -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    [int]$closure.official_result.observed_world_build_count -eq 4 -and
    [int]$closure.official_result.execution_valid_cell_count -eq 4 -and
    [int]$closure.official_result.contextual_common_physical_gate_pass_cell_count -eq 2 -and
    [bool]$closure.official_result.cap_source_factorial_characterization_complete -and
    -not [bool]$closure.official_result.rear_contact_mechanism_selected -and
    -not [bool]$closure.claims.godot_jolt_r23d29_turning -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized
) "consumed R23D58 closure changed"

$pythonHost = Resolve-R23D58Application $Python
$parent = Invoke-R23D58Process -FileName "pwsh" -Arguments @(
    "-NoLogo", "-NoProfile", "-File", $parentClosureAudit
)
Assert-R23D58 ($parent.exit_code -eq 0) (
    "immutable R23D57 closure failed: $($parent.stderr) $($parent.stdout)"
)
Assert-R23D58 (
    $parent.stdout.Contains("QSDK_R23D57_CLOSURE_PASS")
) "immutable R23D57 closure marker changed"

$evaluator = Invoke-R23D58Process -FileName $pythonHost -Arguments @(
    $evaluatorPath, "preflight"
)
Assert-R23D58 ($evaluator.exit_code -eq 0) (
    "evaluator preflight failed: $($evaluator.stderr) $($evaluator.stdout)"
)
$evaluatorReceipt = Get-R23D58MarkerJson $evaluator.stdout (
    "QSDK_R23D58_EVALUATOR_PREFLIGHT "
)
Assert-R23D58 (
    [int]$evaluatorReceipt.declared_cell_count -eq 4 -and
    [int]$evaluatorReceipt.valid_trace_canary_count -eq 4 -and
    [int]$evaluatorReceipt.trace_mutation_rejection_count -eq 30 -and
    [int]$evaluatorReceipt.live_fixture_cap_binding_projection_positive_control_count -eq 4 -and
    [int]$evaluatorReceipt.live_fixture_cap_binding_projection_mutation_rejection_count -eq 21 -and
    [int]$evaluatorReceipt.predeclared_factorial_contrast_canary_count -eq 5 -and
    [int]$evaluatorReceipt.world_build_count -eq 0 -and
    -not [bool]$evaluatorReceipt.physical_execution_authorized
) "evaluator boundary changed"

$factorialArguments = @(
    "-NoLogo", "-NoProfile", "-File", $factorialAudit
)
if ([string]::IsNullOrWhiteSpace($Godot)) {
    $factorialArguments += "-SkipGodot"
} else {
    $factorialArguments += @("-Godot", [IO.Path]::GetFullPath($Godot))
}
$factorial = Invoke-R23D58Process -FileName "pwsh" -Arguments $factorialArguments
Assert-R23D58 ($factorial.exit_code -eq 0) (
    "factorial zero-world audit failed: $($factorial.stderr) $($factorial.stdout)"
)
Assert-R23D58 (
    $factorial.stdout.Contains(
        "QSDK_R23D58_ZERO_WORLD_PASS question=development profiles=4 future_worlds=4"
    )
) "factorial zero-world marker changed"

$closed = Invoke-R23D58Process -FileName "pwsh" -Arguments @(
    "-NoLogo", "-NoProfile", "-File", $closureAudit
)
Assert-R23D58 ($closed.exit_code -eq 0) (
    "immutable R23D58 closure failed: $($closed.stderr) $($closed.stdout)"
)
Assert-R23D58 (
    $closed.stdout.Contains("QSDK_R23D58_CLOSURE_PASS")
) "immutable R23D58 closure marker changed"

$workerText = Get-Content -Raw -LiteralPath $workerPath
$evaluatorText = Get-Content -Raw -LiteralPath $evaluatorPath
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
foreach ($needle in @(
    '"--profile"',
    "live_fixture_actuator_cap_binding_profile_id",
    "R23D58JsonTransportScript.stringify",
    "live_fixture_actuator_cap_binding_execution_deferred_until_after_world_build"
)) {
    Assert-R23D58 ($workerText.Contains($needle)) "worker binding missing: $needle"
}
foreach ($needle in @(
    "_factorial_contrast_report",
    '"posthoc_profile_selection_performed": False',
    '"turning_gate_invoked": False',
    "full_sequences_retained_in_content_addressed_trace"
)) {
    Assert-R23D58 ($evaluatorText.Contains($needle)) "evaluator binding missing: $needle"
}
foreach ($needle in @(
    '$PreflightOnly -xor $RunPhysical',
    '$profileOrder',
    'declared_world_count = 4',
    'all_four_cells_executed_or_retained_as_failures'
)) {
    Assert-R23D58 ($supervisorText.Contains($needle)) "supervisor binding missing: $needle"
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d58_lineage_receipt_v1"
    campaign_id = [string]$campaign.campaign_id
    gate_id = "QSDK-R23D58"
    question_class = "development"
    factorial_profile_count = 4
    factorial_binder_mutation_rejection_count = 12
    terminal_trace_transport_mutation_rejection_count = 32
    production_route_mutation_rejection_count = 20
    evaluator_trace_mutation_rejection_count = 30
    evaluator_factorial_projection_mutation_rejection_count = 21
    predeclared_factorial_contrast_count = 5
    parent_r23d57_closure_passed = $true
    complete_zero_world_audit_passed = $true
    immutable_r23d58_closure_passed = $true
    retained_physical_campaign_consumed = $true
    retained_physical_world_count = 4
    physical_campaign_opened = $false
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D58_LINEAGE_PASS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)
