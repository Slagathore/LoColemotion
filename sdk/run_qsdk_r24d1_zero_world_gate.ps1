[CmdletBinding()]
param(
    [string]$Python = "python",
    [switch]$RequireCleanPushedSource,
    [switch]$CallerHoldsOperationLock
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$auditPath = Join-Path $sdkRoot (
    "recovery\r24d1_canonical_prone_to_standing_design_audit.py"
)
$testPath = Join-Path $repoRoot "tests\test_qsdk_r24d1_declaration.py"
$auditMarkerPrefix = "QSDK_R24D1_DESIGN_AUDIT "

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")

function Assert-R24D1([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R24D1: $Message" }
}

function Invoke-R24D1Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw (
            "QSDK-R24D1 git $($Arguments -join ' ') failed: " +
            ($lines -join " | ")
        )
    }
    return ($lines -join "`n").Trim()
}

function Resolve-R24D1Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D1 (
            Test-Path -LiteralPath $resolved -PathType Leaf
        ) "Application is missing: $resolved"
        return $resolved
    }
    $candidate = Get-Command `
        -Name $Command `
        -CommandType Application `
        -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Invoke-R24D1Checked {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Label
    )
    Push-Location $WorkingDirectory
    try {
        $output = @(& $FileName @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    Assert-R24D1 ($exitCode -eq 0) (
        "$Label failed with exit code $exitCode`: " + ($output -join " | ")
    )
    return @($output | ForEach-Object { [string]$_ })
}

$operationLock = $null
try {
    if (-not $CallerHoldsOperationLock) {
        $operationLock = Enter-SporeSporeLocomotionOperationLock -Role conformance
        Assert-R24D1 ([bool]$operationLock.acquired) (
            "Another conformance or physical workload owns the locomotion lock."
        )
    }

    $root = Invoke-R24D1Git @("rev-parse", "--show-toplevel")
    $remote = Invoke-R24D1Git @("remote", "get-url", "origin")
    $branch = Invoke-R24D1Git @("branch", "--show-current")
    $head = Invoke-R24D1Git @("rev-parse", "HEAD")
    $upstream = Invoke-R24D1Git @("rev-parse", "@{upstream}")
    $status = Invoke-R24D1Git @("status", "--short")
    Assert-R24D1 (
        [IO.Path]::GetFullPath($root) -ceq $repoRoot
    ) "Canonical repository root changed: $root"
    Assert-R24D1 ($remote -ceq $expectedRemote) "Origin changed: $remote"
    Assert-R24D1 ($branch -ceq "main") "Local branch changed: $branch"
    if ($RequireCleanPushedSource) {
        Assert-R24D1 ([string]::IsNullOrEmpty($status)) (
            "Clean-pushed qualification requires an empty worktree: $status"
        )
        Assert-R24D1 ($head -ceq $upstream) (
            "Clean-pushed qualification requires HEAD == upstream."
        )
    }

    foreach ($path in @($auditPath, $testPath)) {
        Assert-R24D1 (
            Test-Path -LiteralPath $path -PathType Leaf
        ) "Required zero-world source is missing: $path"
    }
    $pythonPath = Resolve-R24D1Application $Python
    $auditOutput = Invoke-R24D1Checked `
        -FileName $pythonPath `
        -Arguments @($auditPath) `
        -WorkingDirectory $repoRoot `
        -Label "R24D1 design audit"
    $markers = @($auditOutput | Where-Object {
        $_.StartsWith($auditMarkerPrefix, [StringComparison]::Ordinal)
    })
    Assert-R24D1 ($markers.Count -eq 1) (
        "Design audit emitted $($markers.Count) terminal markers."
    )
    $audit = $markers[0].Substring($auditMarkerPrefix.Length) |
        ConvertFrom-Json
    Assert-R24D1 (
        [bool]$audit.ok -and
        [string]$audit.gate_id -ceq "QSDK-R24D1" -and
        [int]$audit.engine_count -eq 3 -and
        [int]$audit.gate_family_count -eq 7 -and
        [int]$audit.threshold_count -eq 16 -and
        [int]$audit.set_threshold_count -eq 0 -and
        [int]$audit.negative_control_count -eq 12 -and
        [int]$audit.mutation_rejection_count -eq 38 -and
        [bool]$audit.design_declaration_gate_passed -and
        -not [bool]$audit.complete_prephysical_gate_passed -and
        [int]$audit.world_build_count -eq 0 -and
        -not [bool]$audit.physical_acceptance_authority -and
        -not [bool]$audit.release_authority
    ) "Design audit receipt was not exact."

    [void](Invoke-R24D1Checked `
        -FileName $pythonPath `
        -Arguments @($testPath) `
        -WorkingDirectory $repoRoot `
        -Label "R24D1 declaration mutation tests")

    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r24d1_zero_world_gate_receipt_v1"
        ok = $true
        gate_id = "QSDK-R24D1"
        question_class = "non_physical_source_conformance"
        source = [ordered]@{
            root = $root.Replace("\", "/")
            remote = $remote
            branch = $branch
            head = $head
            upstream = $upstream
            clean = [string]::IsNullOrEmpty($status)
            matches_upstream = $head -ceq $upstream
            clean_pushed_required = [bool]$RequireCleanPushedSource
        }
        design_declaration_gate_passed = $true
        complete_prephysical_gate_passed = $false
        required_engine_count = 3
        required_gate_family_count = 7
        required_observation_channel_count = 10
        phase_count = 6
        threshold_count = 16
        set_threshold_count = 0
        negative_control_count = 12
        mutation_rejection_count = 38
        future_physical_question_classes = @("development", "finite_decision")
        thresholds_and_cohorts_frozen = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_question_opened = $false
        physical_campaign_opened = $false
        prone_to_standing_claimed = $false
        cross_engine_equivalence_claimed = $false
        q_sdk_r24_satisfied = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output (
        "QSDK_R24D1_ZERO_WORLD_GATE " +
        ($report | ConvertTo-Json -Depth 20 -Compress)
    )
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}
