#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\three_engine_turning_success_transport_route_v2_implementation.json"
)
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$zeroWorldRunnerPath = Join-Path $repoRoot (
    "sdk\run_three_engine_turning_success_transport_v2_zero_world.ps1"
)
$v1ClosureAuditPath = Join-Path $repoRoot (
    "tests\test_three_engine_turning_production_route_development_closure.ps1"
)
$r23d71ClosureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d71_physical_closure.ps1"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedSourceCommit = "150b94cdbd09bc8083d99f8ac54f038e1594a91b"
$expectedSourceTree = "7dfabd60140953e0dd3b372e981fb09f44838e1b"

function Assert-TransportImplementation([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/transport] v2 implementation audit: $Message"
    }
}

function Invoke-TransportGit([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-TransportImplementation ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-TransportJson([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-TransportSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-TransportAudit([string]$Path) {
    Assert-TransportImplementation (Test-Path -LiteralPath $Path -PathType Leaf) (
        "required audit is missing: $Path"
    )
    $output = @(& pwsh -NoProfile -File $Path 2>&1)
    Assert-TransportImplementation ($LASTEXITCODE -eq 0) (
        "required audit failed: $Path :: $($output -join ' ')"
    )
    foreach ($line in $output) {
        Write-Host $line
    }
}

Assert-TransportImplementation (
    (Invoke-TransportGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/")
) "repository root changed"
Assert-TransportImplementation (
    (Invoke-TransportGit @("remote", "get-url", "origin")) -ceq $expectedRemote
) "repository remote changed"
Assert-TransportImplementation (
    (Invoke-TransportGit @("rev-parse", "$expectedSourceCommit^{tree}")) -ceq
        $expectedSourceTree
) "implementation source tree changed"

foreach ($path in @(
    $implementationPath,
    $supportMatrixPath,
    $releaseContractPath,
    $zeroWorldRunnerPath
)) {
    Assert-TransportImplementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "authority path is missing: $path"
    )
}

$implementation = Get-TransportJson $implementationPath
Assert-TransportImplementation (
    [string]$implementation.schema_version -ceq
        "sporespore_three_engine_turning_success_transport_implementation_v2" -and
    [string]$implementation.status -ceq
        "implementation_complete_complete_zero_world_gate_passed_physical_not_opened" -and
    [string]$implementation.route_id -ceq
        "sporespore_three_engine_turning_success_transport_route_v2"
) "implementation identity changed"
Assert-TransportImplementation (
    [string]$implementation.ledger_scope.subsystem -ceq "turning" -and
    [string]$implementation.ledger_scope.engine_scope -ceq "3e" -and
    [string]$implementation.ledger_scope.authority_mode -ceq "development_ghost" -and
    [string]$implementation.ledger_scope.question_class -ceq "development"
) "ledger classification changed"
Assert-TransportImplementation (
    [string]$implementation.source_authority.implementation_source_commit -ceq
        $expectedSourceCommit -and
    [string]$implementation.source_authority.implementation_source_tree_git_oid -ceq
        $expectedSourceTree -and
    [bool]$implementation.source_authority.source_was_clean_pushed_and_live_equal -and
    [bool]$implementation.source_authority.whole_tree_closes_transitive_tracked_dependencies
) "source authority changed"

$bindings = @($implementation.source_bindings)
Assert-TransportImplementation ($bindings.Count -eq 12) "source binding count changed"
$seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($binding in $bindings) {
    $relative = [string]$binding.path
    Assert-TransportImplementation ($seenPaths.Add($relative)) (
        "duplicate source binding: $relative"
    )
    $absolute = Join-Path $repoRoot ($relative.Replace("/", "\"))
    Assert-TransportImplementation (Test-Path -LiteralPath $absolute -PathType Leaf) (
        "bound path is missing: $relative"
    )
    Assert-TransportImplementation (
        (Get-TransportSha256 $absolute) -ceq [string]$binding.raw_sha256
    ) "bound raw digest changed: $relative"
    Assert-TransportImplementation (
        (Invoke-TransportGit @("rev-parse", "${expectedSourceCommit}:$relative")) -ceq
            [string]$binding.git_blob_oid
    ) "bound source blob changed: $relative"
    Assert-TransportImplementation (
        (Invoke-TransportGit @("rev-parse", "HEAD:$relative")) -ceq
            [string]$binding.git_blob_oid
    ) "live source path diverged after the implementation boundary: $relative"
}

$zeroWorld = $implementation.complete_zero_world_gate
Assert-TransportImplementation (
    [bool]$zeroWorld.passed -and
    [int]$zeroWorld.process_count -eq 8 -and
    [int]$zeroWorld.native_engine_preflight_count -eq 3 -and
    [int]$zeroWorld.evaluator_positive_control_count -eq 3 -and
    [int]$zeroWorld.evaluator_terminal_negative_control_count -eq 6 -and
    [int]$zeroWorld.evaluator_trace_artifact_negative_control_count -eq 8 -and
    [int]$zeroWorld.native_worker_embedded_negative_control_count -eq 6 -and
    [int]$zeroWorld.authorization_negative_control_count -eq 3 -and
    [int]$zeroWorld.total_negative_control_count -eq 23 -and
    [int]$zeroWorld.model_construction_count -eq 0 -and
    [int]$zeroWorld.world_attempt_count -eq 0 -and
    [int]$zeroWorld.world_build_count -eq 0 -and
    -not [bool]$zeroWorld.physical_execution_authorized -and
    -not [bool]$zeroWorld.physical_behavior_thresholds_applied
) "zero-world declaration changed"

$adequacy = $implementation.adequacy
Assert-TransportImplementation (
    [int]$adequacy.declared_native_engine_population_count -eq 3 -and
    [bool]$adequacy.declared_native_engine_population_complete -and
    [int]$adequacy.development_arm_count -eq 1 -and
    [int]$adequacy.controller_step_count_per_engine -eq 2 -and
    -not [bool]$adequacy.sampling_used -and
    $null -eq $adequacy.equivalence_margin -and
    $null -eq $adequacy.non_inferiority_margin -and
    $null -eq $adequacy.behavior_threshold -and
    -not [string]::IsNullOrWhiteSpace([string]$adequacy.argument)
) "adequacy or margin declaration changed"

$nextPhysical = $implementation.next_physical
Assert-TransportImplementation (
    [string]$nextPhysical.status -ceq "not_opened" -and
    [string]$nextPhysical.question_class -ceq "development" -and
    [int]$nextPhysical.declared_world_count -eq 3 -and
    [int]$nextPhysical.controller_step_count_per_world -eq 2 -and
    [bool]$nextPhysical.serial_execution_required -and
    [bool]$nextPhysical.complete_zero_world_gate_repeated_inside_supervisor -and
    [bool]$nextPhysical.clean_pushed_local_origin_live_equality_required -and
    [bool]$nextPhysical.append_only_attempt_required -and
    -not [bool]$nextPhysical.behavioral_success_question_asked -and
    -not [bool]$nextPhysical.turning_threshold_applied
) "bounded physical successor changed"
Assert-TransportImplementation (
    (@($nextPhysical.ordered_cell_ids) -join "|") -ceq (
        "turning_success_transport_v2__godot_jolt__s21516__positive_heading|" +
        "turning_success_transport_v2__rapier_parry__s21516__positive_heading|" +
        "turning_success_transport_v2__mujoco__s21516__positive_heading"
    )
) "bounded physical cell population changed"
Assert-TransportImplementation (
    @($implementation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "a forbidden scientific or release claim became true"

$support = Get-TransportJson $supportMatrixPath
$supportRoute = $support.locomotion_modes.three_engine_turning_success_transport_route_v2
Assert-TransportImplementation (
    [string]$supportRoute.status -ceq
        "implementation_complete_complete_zero_world_gate_passed_physical_not_opened" -and
    [string]$supportRoute.implementation_path -ceq
        "sdk/turning/three_engine_turning_success_transport_route_v2_implementation.json" -and
    [string]$supportRoute.implementation_raw_sha256 -ceq
        (Get-TransportSha256 $implementationPath) -and
    [string]$supportRoute.implementation_source_commit -ceq $expectedSourceCommit -and
    [string]$supportRoute.implementation_source_tree_git_oid -ceq $expectedSourceTree -and
    [bool]$supportRoute.complete_zero_world_gate_passed -and
    -not [bool]$supportRoute.physical_smoke_opened -and
    -not [bool]$supportRoute.portable_basic_turning -and
    -not [bool]$supportRoute.q_sdk_r23_satisfied -and
    -not [bool]$supportRoute.release_authorized
) "support-matrix projection changed"

$release = Get-TransportJson $releaseContractPath
$turningGate = @($release.gates | Where-Object { $_.gate_id -ceq "QSDK-R23" })
Assert-TransportImplementation ($turningGate.Count -eq 1) "QSDK-R23 gate count changed"
$releaseRoute = $turningGate[0].proof.current_transport_development_successor
Assert-TransportImplementation (
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    [string]$releaseRoute.status -ceq
        "implementation_complete_complete_zero_world_gate_passed_physical_not_opened" -and
    [string]$releaseRoute.implementation_path -ceq
        "sdk/turning/three_engine_turning_success_transport_route_v2_implementation.json" -and
    [string]$releaseRoute.implementation_raw_sha256 -ceq
        (Get-TransportSha256 $implementationPath) -and
    [bool]$releaseRoute.complete_zero_world_gate_passed -and
    -not [bool]$releaseRoute.physical_smoke_opened -and
    -not [bool]$releaseRoute.q_sdk_r23_satisfied -and
    -not [bool]$releaseRoute.release_authorized
) "release-contract projection changed"

Invoke-TransportAudit $v1ClosureAuditPath
Invoke-TransportAudit $r23d71ClosureAuditPath
Invoke-TransportAudit $zeroWorldRunnerPath

Write-Host (
    "[turning/transport] PASS v2 implementation freeze: " +
    "source=150b94cd bindings=12 engines=3 negatives=23 models=0 worlds=0"
)
