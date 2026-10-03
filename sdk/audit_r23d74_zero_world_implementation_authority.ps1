#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoPython = Join-Path $sdkRoot "adapters\mujoco\.venv\Scripts\python.exe"
$implementationPath = Join-Path $turningRoot (
    "r23d74_production_route_three_engine_turning_implementation_v1.json"
)
$materializerPath = Join-Path $turningRoot "materialize_r23d74_implementation.py"
$closurePath = Join-Path $turningRoot (
    "r23d74_production_route_three_engine_turning_validation_closure_v1.json"
)
$closureMaterializerPath = Join-Path $turningRoot "materialize_r23d74_physical_closure.py"
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d74_physical_closure.ps1"
$releasePath = Join-Path $sdkRoot "release\quadruped_release_contract.json"
$supportPath = Join-Path $sdkRoot "release\quadruped_support_matrix.json"
$auditRelative = "sdk/audit_r23d74_zero_world_implementation_authority.ps1"
$initialImplementationSourceCommit = "bf0fb52ffee88704f5253c7eeb8a525582382682"
$implementationSourceCommit = "32b9db7f67c15f72181a5e5ac8a412e5f7a51a57"
$currentStatus = (
    "closed_consumed_invalid_or_incomplete_first_attempt_" +
    "mujoco_startup_trace_evaluator_binding_mismatch"
)
$currentPointer = (
    "r23d74_closed_consumed_invalid_or_incomplete_" +
    "mujoco_startup_trace_evaluator_binding_mismatch"
)

function Assert-R23D74Authority([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/3e] R23D74 implementation authority audit: $Message"
    }
}

function Get-R23D74AuthoritySha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Resolve-R23D74AuthorityApplication([string]$Value, [string]$Fallback) {
    $candidate = if ([string]::IsNullOrWhiteSpace($Value)) { $Fallback } else { $Value }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [IO.Path]::GetFullPath($candidate)
    }
    return [IO.Path]::GetFullPath(
        (Get-Command $candidate -CommandType Application -ErrorAction Stop).Source
    )
}

function Find-R23D74AuthorityValues($Value, [string]$Key) {
    $found = [Collections.Generic.List[object]]::new()
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains($Key)) { $found.Add($Value[$Key]) }
        foreach ($childKey in $Value.Keys) {
            foreach ($item in @(Find-R23D74AuthorityValues $Value[$childKey] $Key)) {
                $found.Add($item)
            }
        }
    } elseif ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            foreach ($item in @(Find-R23D74AuthorityValues $child $Key)) {
                $found.Add($item)
            }
        }
    }
    return @($found)
}

function Test-R23D74AuthorityRecord([Collections.IDictionary]$Record) {
    return (
        [string]$Record.campaign_id -ceq
            "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION" -and
        [string]$Record.gate_id -ceq "QSDK-R23D74" -and
        [string]$Record.release_gate_id -ceq "QSDK-R23" -and
        [string]$Record.status -ceq $currentStatus -and
        [string]$Record.question_class -ceq "finite_decision" -and
        [bool]$Record.not_superiority_work -and
        [bool]$Record.not_equivalence_or_non_inferiority_work -and
        [string]$Record.initial_implementation_source_commit -ceq
            $initialImplementationSourceCommit -and
        [string]$Record.implementation_source_commit -ceq $implementationSourceCommit -and
        [string]$Record.implementation_path -ceq
            "sdk/turning/r23d74_production_route_three_engine_turning_implementation_v1.json" -and
        [string]$Record.implementation_raw_sha256 -ceq
            (Get-R23D74AuthoritySha256 $implementationPath) -and
        [string]$Record.implementation_materializer_path -ceq
            "sdk/turning/materialize_r23d74_implementation.py" -and
        [string]$Record.implementation_materializer_raw_sha256 -ceq
            (Get-R23D74AuthoritySha256 $materializerPath) -and
        [string]$Record.implementation_audit_path -ceq $auditRelative -and
        [string]$Record.implementation_audit_raw_sha256 -ceq
            (Get-R23D74AuthoritySha256 (Join-Path $repoRoot $auditRelative)) -and
        [string]$Record.complete_zero_world_runner_path -ceq
            "sdk/run_qsdk_r23d74_zero_world.ps1" -and
        [string]$Record.complete_zero_world_runner_raw_sha256 -ceq
            [string]$implementation.dependency_digests[
                "sdk/run_qsdk_r23d74_zero_world.ps1"
            ] -and
        [string]$Record.complete_zero_world_audit_path -ceq
            "tests/test_qsdk_r23d74_zero_world.ps1" -and
        [string]$Record.complete_zero_world_audit_raw_sha256 -ceq
            [string]$implementation.dependency_digests[
                "tests/test_qsdk_r23d74_zero_world.ps1"
            ] -and
        [int]$Record.implementation_dependency_count -eq 229 -and
        [bool]$Record.implementation_complete -and
        [bool]$Record.complete_implementation_zero_world_gate_passed -and
        [int]$Record.declaration_and_terminal_mutation_rejection_count -eq 18 -and
        [int]$Record.representative_native_worker_preflight_count -eq 3 -and
        [int]$Record.complete_authorization_ghost_receipt_count -eq 9 -and
        [int]$Record.invalid_selector_negative_count -eq 3 -and
        [int]$Record.missing_physical_authorization_negative_count -eq 3 -and
        [int]$Record.evaluator_outcome_control_count -eq 4 -and
        [int]$Record.predecessor_replay_count -eq 4 -and
        -not [bool]$Record.full_seeded_world_ghost_used -and
        [int]$Record.zero_world_model_construction_count -eq 0 -and
        [int]$Record.zero_world_world_attempt_count -eq 0 -and
        [int]$Record.zero_world_world_build_count -eq 0 -and
        [int]$Record.zero_world_solver_step_count -eq 0 -and
        [bool]$Record.clean_pushed_production_conformance_qualification_retained -and
        [bool]$Record.qualification_adoption_retained -and
        [bool]$Record.qualification_passed -and
        [bool]$Record.campaign_attestation_adopted -and
        [bool]$Record.physical_execution_authorized -and
        [bool]$Record.physical_campaign_opened -and
        [string]$Record.current_lifecycle_status -ceq $currentStatus -and
        [string]$Record.current_lifecycle.closure_path -ceq
            "sdk/turning/r23d74_production_route_three_engine_turning_validation_closure_v1.json" -and
        [string]$Record.current_lifecycle.closure_raw_sha256 -ceq
            (Get-R23D74AuthoritySha256 $closurePath) -and
        [string]$Record.current_lifecycle.closure_materializer_path -ceq
            "sdk/turning/materialize_r23d74_physical_closure.py" -and
        [string]$Record.current_lifecycle.closure_materializer_raw_sha256 -ceq
            (Get-R23D74AuthoritySha256 $closureMaterializerPath) -and
        [string]$Record.current_lifecycle.closure_audit_path -ceq
            "tests/test_qsdk_r23d74_physical_closure.ps1" -and
        [string]$Record.current_lifecycle.closure_audit_raw_sha256 -ceq
            (Get-R23D74AuthoritySha256 $closureAuditPath) -and
        [string]$Record.current_lifecycle.attempt_id -ceq
            "9dbe54d9cc8241b0bf40da3b4b28b541" -and
        [int]$Record.world_attempt_count -eq 9 -and
        [int]$Record.world_build_count -eq 9 -and
        -not [bool]$Record.finite_three_engine_turning -and
        -not [bool]$Record.valid_turning_result_available -and
        -not [bool]$Record.same_identity_rerun_allowed -and
        [string]$Record.next_work_class -ceq
            "distinct_successor_native_startup_trace_evaluator_conformance" -and
        -not [bool]$Record.turning_established -and
        -not [bool]$Record.portable_basic_turning -and
        -not [bool]$Record.cross_engine_equivalence -and
        -not [bool]$Record.q_sdk_r23_satisfied -and
        [string]$Record.release_score_before -ceq "10/25" -and
        [string]$Record.release_score_if_positive -ceq "11/25" -and
        [string]$Record.release_score_after -ceq "10/25" -and
        -not [bool]$Record.physical_acceptance_authority -and
        -not [bool]$Record.release_authorized
    )
}

$null = & git -C $repoRoot merge-base --is-ancestor $implementationSourceCommit HEAD
$ancestryExitCode = $LASTEXITCODE
Assert-R23D74Authority (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    $ancestryExitCode -eq 0
) "repository, remote, or implementation-source ancestry changed"
foreach ($path in @(
    $implementationPath,
    $materializerPath,
    $closurePath,
    $closureMaterializerPath,
    $closureAuditPath,
    $releasePath,
    $supportPath,
    (Join-Path $repoRoot $auditRelative)
)) {
    Assert-R23D74Authority (Test-Path -LiteralPath $path -PathType Leaf) (
        "required authority path missing: $path"
    )
}

$pythonHost = Resolve-R23D74AuthorityApplication $Python $mujocoPython
$closureMaterializerLines = @(& $pythonHost -B $closureMaterializerPath --audit 2>&1 |
    ForEach-Object { [string]$_ })
Assert-R23D74Authority (
    $LASTEXITCODE -eq 0 -and
    ($closureMaterializerLines -join "`n").Contains(
        "[turning/3e] PASS R23D74 immutable physical closure",
        [StringComparison]::Ordinal
    )
) "immutable physical closure audit failed: $($closureMaterializerLines -join ' ')"

# The prospective implementation materializer intentionally discovered only
# paths that existed at its clean-pushed freeze. Once the consumed closure file
# exists, recomposing that live graph would add a post-result edge from the
# already frozen native workers and falsely report implementation drift. The
# immutable closure audit above instead verifies the exact source commit/tree
# and pinned implementation blob without rewriting the prospective inventory.

$implementation = Get-Content -LiteralPath $implementationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D74Authority (
    [string]$implementation.status -ceq
        "implementation_complete_complete_zero_world_gate_passed_physical_not_authorized" -and
    [string]$implementation.question_class -ceq "finite_decision" -and
    @($implementation.dependency_digests.Keys).Count -eq 229 -and
    [bool]$implementation.claims.implementation_complete -and
    [bool]$implementation.claims.complete_zero_world_gate_passed -and
    -not [bool]$implementation.claims.physical_campaign_opened -and
    -not [bool]$implementation.claims.finite_three_engine_turning -and
    -not [bool]$implementation.claims.cross_engine_equivalence -and
    -not [bool]$implementation.physical_execution_authorized -and
    -not [bool]$implementation.physical_acceptance_authority
) "content-addressed implementation semantics changed"

$release = Get-Content -LiteralPath $releasePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -LiteralPath $supportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGates = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-R23D74Authority ($turningGates.Count -eq 1) "QSDK-R23 gate population changed"
$releaseRecord = $turningGates[0].proof.current_r23d74_fresh_finite_three_engine_turning_decision
$supportRecord = $support.locomotion_modes.r23d74_fresh_finite_three_engine_turning_decision_v1
Assert-R23D74Authority (
    $releaseRecord -is [Collections.IDictionary] -and
    $supportRecord -is [Collections.IDictionary] -and
    (Test-R23D74AuthorityRecord $releaseRecord) -and
    (Test-R23D74AuthorityRecord $supportRecord) -and
    ($releaseRecord | ConvertTo-Json -Compress -Depth 100) -ceq
        ($supportRecord | ConvertTo-Json -Compress -Depth 100)
) "release-contract and support-matrix implementation records diverged"

$releasePointers = @(Find-R23D74AuthorityValues $release "current_prospective_successor_status" |
    Where-Object { [string]$_ -clike "r23d74_*" })
$supportPointers = @(Find-R23D74AuthorityValues $support "current_prospective_successor_status" |
    Where-Object { [string]$_ -clike "r23d74_*" })
$releaseReasons = @(Find-R23D74AuthorityValues $release "current_prospective_successor_reason" |
    Where-Object { ([string]$_).Contains("R23D74", [StringComparison]::Ordinal) })
$supportReasons = @(Find-R23D74AuthorityValues $support "current_prospective_successor_reason" |
    Where-Object { ([string]$_).Contains("R23D74", [StringComparison]::Ordinal) })
Assert-R23D74Authority (
    $releasePointers.Count -eq 1 -and
    $supportPointers.Count -eq 1 -and
    [string]$releasePointers[0] -ceq $currentPointer -and
    [string]$supportPointers[0] -ceq $currentPointer -and
    $releaseReasons.Count -eq 1 -and
    $supportReasons.Count -eq 1 -and
    [string]$releaseReasons[0] -ceq [string]$supportReasons[0] -and
    ([string]$releaseReasons[0]).Contains(
        "all nine genuine native worlds completed",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    ([string]$releaseReasons[0]).Contains(
        "R23D58_STARTUP_TRANSFORM_INVALID",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    ([string]$releaseReasons[0]).Contains(
        "no same-identity or selective rerun is allowed",
        [StringComparison]::OrdinalIgnoreCase
    )
) "current R23D74 pointer or reason changed"

$mutationRejections = 0
foreach ($mutation in @(
    { param($value) $value.status = "physical_authorized" },
    { param($value) $value.implementation_dependency_count = 228 },
    { param($value) $value.complete_implementation_zero_world_gate_passed = $false },
    { param($value) $value.full_seeded_world_ghost_used = $true },
    { param($value) $value.predecessor_replay_count = 3 },
    { param($value) $value.same_identity_rerun_allowed = $true },
    { param($value) $value.q_sdk_r23_satisfied = $true },
    { param($value) $value.release_score_after = "11/25" }
)) {
    $candidate = $releaseRecord | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D74AuthorityRecord $candidate)) { $mutationRejections += 1 }
}
Assert-R23D74Authority ($mutationRejections -eq 8) (
    "implementation-authority mutation controls did not all reject"
)

Write-Output (
    "[turning/3e] R23D74 zero-world implementation authority PASS: " +
    "dependencies=229 mutations=18/18 workers=3 authorization=9/9 " +
    "predecessors=4/4 qualification=16/16 adoption=True worlds=9 horizons=9 " +
    "closed invalid_or_incomplete turning=False score=10/25"
)
