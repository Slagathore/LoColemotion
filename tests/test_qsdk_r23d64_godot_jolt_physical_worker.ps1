[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$workerScript = "res://tests/test_sdk_qsdk_r23d64_godot_jolt_physical_worker.gd"
$workerSourceRelativePath = "tests/test_sdk_qsdk_r23d64_godot_jolt_physical_worker.gd"
$workerGateRelativePath = "tests/test_qsdk_r23d64_godot_jolt_physical_worker.ps1"
$implementationRelativePath = (
    "sdk/turning/r23d64_selected_profile_three_engine_turning_validation_" +
    "implementation_v1.json"
)
$publicProfileRouteRelativePath = (
    "scripts/lab/gait/sdk_godot_jolt_public_actuator_cap_profile_binding.gd"
)
$physicalRunnerRelativePath = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
$terminationHelperRelativePath = "sdk/godot_receipt_terminated_process.ps1"
$stageId = "rapier_launch_contract_repaired_selected_profile_matched_three_engine_turning_validation"
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$profileSha256 = (
    "sha256:" +
    "b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
$hostMappingId = "sporespore_godot_hinge_maximum_impulse_cap_mapping_v1"
$policyId = "sporespore_godot_jolt_public_actuator_cap_profile_binding_v1"
$campaignId = (
    "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)
$preflightMarker = "QSDK_R23D64_GODOT_JOLT_PREFLIGHT "
$failureMarker = "QSDK_R23D64_GODOT_JOLT_FAILURE "
$terminalMarker = "QSDK_R23D64_GODOT_JOLT_TERMINAL "
$terminationReadyMarker = "QSDK_R23D64_GODOT_SUPERVISOR_TERMINATION_READY "
$orderedArms = @(
    [ordered]@{ id = "reference_zero"; offset = 0.0 },
    [ordered]@{ id = "positive_heading"; offset = 0.2 },
    [ordered]@{ id = "negative_heading"; offset = -0.2 }
)
$authorizationEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D64_FREEZE",
    "SPORESPORE_QSDK_R23D64_ATTEMPT",
    "SPORESPORE_QSDK_R23D64_TOKEN",
    "SPORESPORE_QSDK_R23D64_STAGE",
    "SPORESPORE_QSDK_R23D64_CELL",
    "SPORESPORE_QSDK_R23D64_ENGINE",
    "SPORESPORE_QSDK_R23D64_ATTEMPT_ROOT"
)
$workerEnvironmentNames = $authorizationEnvironmentNames + @(
    "SPORESPORE_QSDK_R23D64_PYTHON",
    "SPORESPORE_QSDK_R23D64_POWERSHELL",
    "SPORESPORE_QSDK_R23D64_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D64_TERMINATION_NONCE",
    "SPORESPORE_QSDK_R23D60_FREEZE",
    "SPORESPORE_QSDK_R23D60_ATTEMPT",
    "SPORESPORE_QSDK_R23D60_TOKEN",
    "SPORESPORE_QSDK_R23D60_STAGE",
    "SPORESPORE_QSDK_R23D60_CELL",
    "SPORESPORE_QSDK_R23D60_ENGINE",
    "SPORESPORE_QSDK_R23D60_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D60_PYTHON",
    "SPORESPORE_QSDK_R23D60_POWERSHELL",
    "SPORESPORE_QSDK_R23D60_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D60_TERMINATION_NONCE",
    "SPORESPORE_QSDK_R23D59_FREEZE",
    "SPORESPORE_QSDK_R23D59_ATTEMPT",
    "SPORESPORE_QSDK_R23D58_FREEZE",
    "SPORESPORE_QSDK_R23D58_ATTEMPT",
    "SPORESPORE_QSDK_R23D48_FREEZE",
    "SPORESPORE_QSDK_R23D48_ATTEMPT"
)

. (Join-Path $repoRoot $terminationHelperRelativePath)

function Assert-R23D64GodotWorker {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D64GodotWorkerSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant())"
}

function New-R23D64WorkerArguments {
    param([string]$ArmId)
    return @(
        "--stage", $stageId,
        "--onset", "onset_600",
        "--seed", "23171",
        "--profile", $profileId,
        "--arm", $ArmId
    )
}

function Invoke-R23D64GodotWorker {
    param(
        [string[]]$UserArguments,
        [int]$ExpectedExitCode,
        [string]$ExpectedMarker
    )
    $processArguments = @(
        "--headless",
        "--path", $repoRoot,
        "--script", $workerScript,
        "--"
    ) + $UserArguments
    $expectedReceiptKind = if ($ExpectedMarker -ceq $preflightMarker) {
        "preflight"
    } elseif ($ExpectedMarker -ceq $failureMarker) {
        "failure"
    } elseif ($ExpectedMarker -ceq $terminalMarker) {
        "terminal"
    } else {
        throw "R23D64 Godot worker expected marker is unsupported: $ExpectedMarker"
    }
    $terminationNonce = [Guid]::NewGuid().ToString("N")
    $workerEnvironment = @{
        "SPORESPORE_QSDK_R23D64_SUPERVISED_TERMINATION" = "1"
        "SPORESPORE_QSDK_R23D64_TERMINATION_NONCE" = $terminationNonce
    }
    $process = Invoke-SporeSporeGodotReceiptTerminatedProcess `
        -FileName $godotPath `
        -Arguments $processArguments `
        -WorkingDirectory $repoRoot `
        -ReadyMarkerPrefix $terminationReadyMarker `
        -ExpectedNonce $terminationNonce `
        -Environment $workerEnvironment `
        -ScrubEnvironmentNames $workerEnvironmentNames `
        -TimeoutSeconds 300
    $lines = @(
        @([string]$process.stdout -split "`r?`n") |
            Where-Object { -not [string]::IsNullOrEmpty([string]$_) } |
            ForEach-Object { [string]$_ }
    )
    $stderrLines = @(
        @([string]$process.stderr -split "`r?`n") |
            Where-Object { -not [string]::IsNullOrEmpty([string]$_) } |
            ForEach-Object { [string]$_ }
    )
    $matches = @(
        $lines | Where-Object {
            $_.StartsWith($ExpectedMarker, [StringComparison]::Ordinal)
        }
    )
    $diagnosticLines = @($lines) + @($stderrLines)
    Assert-R23D64GodotWorker (
        [int]$process.exit_code -eq $ExpectedExitCode -and
        -not [bool]$process.timed_out -and
        [bool]$process.termination_protocol_valid -and
        [bool]$process.supervisor_terminated -and
        [int]$process.termination_ready_receipt.requested_exit_code -eq
            $ExpectedExitCode -and
        [string]$process.termination_ready_receipt.worker_receipt_kind -ceq
            $expectedReceiptKind -and
        $matches.Count -eq 1 -and
        @($diagnosticLines | Where-Object {
            $_.Contains("SCRIPT ERROR") -or $_.StartsWith("ERROR:")
        }).Count -eq 0
    ) (
        "R23D64 Godot worker process invalid: expected_exit=$ExpectedExitCode " +
        "semantic_exit=$($process.exit_code) host_exit=$($process.host_exit_code) " +
        "marker=$ExpectedMarker protocol_failure=" +
        "$($process.termination_protocol_failure_code)`n" +
        ($diagnosticLines -join [Environment]::NewLine)
    )
    return ($matches[0].Substring($ExpectedMarker.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100)
}

Assert-R23D64GodotWorker ($repoRoot -ceq $expectedRoot) (
    "R23D64 Godot worker repository root changed: $repoRoot"
)
$gitRoot = [IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
$remote = (& git -C $repoRoot remote get-url origin).Trim()
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-R23D64GodotWorker (
    $LASTEXITCODE -eq 0 -and
    $gitRoot -ceq $expectedRoot -and
    $remote -ceq $expectedRemote -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$"
) "R23D64 Godot worker Git identity changed"
$godotPath = [IO.Path]::GetFullPath($Godot)
Assert-R23D64GodotWorker (
    Test-Path -LiteralPath $godotPath -PathType Leaf
) "R23D64 Godot runtime missing: $godotPath"

$implementationPath = Join-Path $repoRoot $implementationRelativePath
$workerSourcePath = Join-Path $repoRoot $workerSourceRelativePath
$workerGatePath = Join-Path $repoRoot $workerGateRelativePath
$publicProfileRoutePath = Join-Path $repoRoot $publicProfileRouteRelativePath
$physicalRunnerPath = Join-Path $repoRoot $physicalRunnerRelativePath
$terminationHelperPath = Join-Path $repoRoot $terminationHelperRelativePath
foreach ($path in @(
    $implementationPath,
    $workerSourcePath,
    $workerGatePath,
    $publicProfileRoutePath,
    $physicalRunnerPath,
    $terminationHelperPath
)) {
    Assert-R23D64GodotWorker (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "R23D64 Godot worker authority file missing: $path"
}
$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$godotWorker = $implementation["workers"]["godot_jolt"]
$implementationClaims = $implementation["claims"]
Assert-R23D64GodotWorker (
    [string]$implementation["schema_version"] -ceq
        "sporespore_qsdk_r23d64_selected_profile_three_engine_turning_validation_implementation_v1" -and
    [string]$implementation["status"] -ceq
        "prospective_campaign_machinery_implemented_receipt_schema_and_rapier_launcher_contract_gates_passed_complete_zero_world_gate_passed_physical_not_opened" -and
    [string]$implementation["campaign_id"] -ceq $campaignId -and
    [string]$implementation["gate_id"] -ceq "QSDK-R23D64" -and
    [string]$implementation["question_class"] -ceq "finite_decision" -and
    -not [bool]$implementation["physical_campaign_opened"] -and
    [int]$implementation["declared_world_count"] -eq 9 -and
    [string]$implementation["profile_id"] -ceq $profileId -and
    [string]$implementation["profile_sha256"] -ceq $profileSha256 -and
    [int]$implementation["implemented_native_dependency_route_count"] -eq 3 -and
    [int]$implementation["implemented_native_worker_count"] -eq 3 -and
    [string]$godotWorker["path"] -ceq $workerSourceRelativePath -and
    [string]$godotWorker["raw_sha256"] -ceq
        (Get-R23D64GodotWorkerSha256 $workerSourcePath) -and
    [bool]$godotWorker["implementation_complete"] -and
    [string]$godotWorker["production_public_profile_route_path"] -ceq
        $publicProfileRouteRelativePath -and
    [string]$godotWorker["production_public_profile_route_raw_sha256"] -ceq
        (Get-R23D64GodotWorkerSha256 $publicProfileRoutePath) -and
    [string]$godotWorker["production_physical_runner_path"] -ceq
        $physicalRunnerRelativePath -and
    [string]$godotWorker["production_physical_runner_raw_sha256"] -ceq
        (Get-R23D64GodotWorkerSha256 $physicalRunnerPath) -and
    [string]$godotWorker["zero_world_worker_gate_path"] -ceq
        $workerGateRelativePath -and
    [string]$godotWorker["zero_world_worker_gate_raw_sha256"] -ceq
        (Get-R23D64GodotWorkerSha256 $workerGatePath) -and
    [string]$godotWorker["supervised_termination_helper_path"] -ceq
        $terminationHelperRelativePath -and
    [string]$godotWorker["supervised_termination_helper_raw_sha256"] -ceq
        (Get-R23D64GodotWorkerSha256 $terminationHelperPath) -and
    [string]$godotWorker["supervised_termination_protocol_id"] -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [int]$godotWorker["declared_preflight_cell_count"] -eq 3 -and
    [int]$godotWorker["negative_control_rejection_count"] -eq 11 -and
    [int]$godotWorker["route_write_count"] -eq 8 -and
    [int]$godotWorker["route_readback_count"] -eq 8 -and
    [int]$godotWorker["model_construction_count"] -eq 0 -and
    [int]$godotWorker["world_attempt_count"] -eq 0 -and
    [int]$godotWorker["world_build_count"] -eq 0 -and
    [bool]$godotWorker["zero_world_worker_gate_passed"] -and
    -not [bool]$godotWorker["physical_execution_authorized"] -and
    [bool]$implementationClaims["godot_worker_implementation_complete"] -and
    [bool]$implementationClaims["godot_worker_zero_world_gate_passed"] -and
    [bool]$implementationClaims["rapier_public_profile_dependency_route_complete"] -and
    [bool]$implementationClaims["rapier_worker_implementation_complete"] -and
    [bool]$implementationClaims["mujoco_public_profile_dependency_route_complete"] -and
    [bool]$implementationClaims["mujoco_worker_implementation_complete"] -and
    [bool]$implementationClaims["native_routes_and_workers_complete"] -and
    [bool]$implementationClaims["implementation_complete"] -and
    [bool]$implementationClaims["complete_zero_world_gate_passed"] -and
    [bool]$implementationClaims["complete_transitive_dependency_inventory_proved"] -and
    -not [bool]$implementationClaims["physical_world_opened"] -and
    -not [bool]$implementationClaims["finite_three_engine_turning"] -and
    -not [bool]$implementationClaims["q_sdk_r23_satisfied"] -and
    -not [bool]$implementationClaims["release_authority"] -and
    -not [bool]$implementationClaims["physical_acceptance_authority"]
) "R23D64 Godot worker implementation authority changed"

$savedEnvironment = @{}
foreach ($name in $authorizationEnvironmentNames) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable(
        $name,
        [EnvironmentVariableTarget]::Process
    )
    [Environment]::SetEnvironmentVariable(
        $name,
        $null,
        [EnvironmentVariableTarget]::Process
    )
}

try {
    $positiveCells = @()
    foreach ($arm in $orderedArms) {
        $arguments = @("--preflight-only") + (
            New-R23D64WorkerArguments -ArmId ([string]$arm.id)
        )
        $receipt = Invoke-R23D64GodotWorker `
            -UserArguments $arguments `
            -ExpectedExitCode 0 `
            -ExpectedMarker $preflightMarker
        $expectedCellId = (
            "godot_jolt__s23171__selected_profile__" + [string]$arm.id
        )
        $entrypoint = $receipt.entrypoint_preflight
        Assert-R23D64GodotWorker (
            [bool]$receipt.ok -and
            [string]$receipt.schema_version -ceq
                "sporespore_qsdk_r23d64_godot_jolt_worker_preflight_v1" -and
            [string]$receipt.campaign_id -ceq $campaignId -and
            [string]$receipt.gate_id -ceq "QSDK-R23D64" -and
            [string]$receipt.engine_id -ceq "godot_jolt" -and
            [string]$receipt.stage_id -ceq $stageId -and
            [string]$receipt.cell_id -ceq $expectedCellId -and
            [int]$receipt.campaign_seed -eq 23171 -and
            [string]$receipt.profile_id -ceq $profileId -and
            [string]$receipt.profile_sha256 -ceq $profileSha256 -and
            [string]$receipt.host_mapping_id -ceq $hostMappingId -and
            [string]$receipt.arm_id -ceq [string]$arm.id -and
            [double]$receipt.turn_heading_offset_rad -eq [double]$arm.offset -and
            [string]$receipt.public_profile_binding_policy_id -ceq $policyId -and
            [bool]$receipt.compiled_initial_perturbation_matches_declaration -and
            [int]$receipt.expected_matrix_cell_count -eq 9 -and
            @($receipt.expected_matrix_cell_ids).Count -eq 9 -and
            [string]$receipt.expected_matrix_cell_ids[0] -ceq
                "godot_jolt__s23171__selected_profile__reference_zero" -and
            [string]$receipt.expected_matrix_cell_ids[8] -ceq
                "mujoco__s23171__selected_profile__negative_heading" -and
            [bool]$receipt.authorization_validates_complete_nine_cell_matrix -and
            [bool]$receipt.public_profile_resolution_deferred_to_exact_preworld_host_route -and
            [string]$entrypoint.sdk_live_fixture_actuator_cap_binding_policy_id -ceq
                $policyId -and
            [string]$entrypoint.sdk_live_fixture_actuator_cap_binding_profile_id -ceq
                $profileId -and
            -not [bool]$entrypoint.sdk_live_fixture_actuator_cap_binding_executed -and
            [int]$receipt.model_construction_count -eq 0 -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            -not [bool]$receipt.physical_execution_authorized -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "R23D64 Godot worker positive preflight invalid: $($arm.id)"
        $positiveCells += [string]$receipt.cell_id
    }

    $base = New-R23D64WorkerArguments -ArmId "reference_zero"
    $mutationCases = @(
        [ordered]@{
            id = "wrong_stage"
            args = @("--preflight-only") + ($base.Clone())
            replaceIndex = 2
            replaceValue = "wrong_stage"
            code = "QSDK_R23D64_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "wrong_onset"
            args = @("--preflight-only") + ($base.Clone())
            replaceIndex = 4
            replaceValue = "onset_601"
            code = "QSDK_R23D64_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "wrong_seed"
            args = @("--preflight-only") + ($base.Clone())
            replaceIndex = 6
            replaceValue = "23168"
            code = "QSDK_R23D64_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "wrong_profile"
            args = @("--preflight-only") + ($base.Clone())
            replaceIndex = 8
            replaceValue = "unknown_profile"
            code = "QSDK_R23D64_GJT_CELL_IDENTITY_INVALID"
        },
        [ordered]@{
            id = "wrong_arm"
            args = @("--preflight-only") + ($base.Clone())
            replaceIndex = 10
            replaceValue = "wrong_arm"
            code = "QSDK_R23D64_GJT_CELL_IDENTITY_INVALID"
        }
    )
    foreach ($case in $mutationCases) {
        $case.args[[int]$case.replaceIndex] = [string]$case.replaceValue
    }
    $mutationCases += @(
        [ordered]@{
            id = "duplicate_preflight_flag"
            args = @("--preflight-only", "--preflight-only") + $base
            code = "QSDK_R23D64_GJT_ARGUMENT_UNKNOWN:--preflight-only"
        },
        [ordered]@{
            id = "unknown_argument"
            args = @("--preflight-only", "--unknown") + $base
            code = "QSDK_R23D64_GJT_ARGUMENT_UNKNOWN:--unknown"
        },
        [ordered]@{
            id = "source_commit_during_preflight"
            args = @("--preflight-only") + $base +
                @("--source-commit", $sourceCommit)
            code = "QSDK_R23D64_GJT_ARGUMENTS_INVALID"
        },
        [ordered]@{
            id = "physical_missing_source_commit"
            args = $base
            code = "QSDK_R23D64_GJT_ARGUMENTS_INVALID"
        },
        [ordered]@{
            id = "physical_missing_authorization"
            args = $base + @("--source-commit", $sourceCommit)
            code = "QSDK_R23D64_GJT_PHYSICAL_AUTHORIZATION_REQUIRED"
            marker = $terminalMarker
        },
        [ordered]@{
            id = "authorization_preflight_missing_authorization"
            args = @("--authorization-preflight-only") + $base +
                @("--source-commit", $sourceCommit)
            code = "QSDK_R23D64_GJT_PHYSICAL_AUTHORIZATION_REQUIRED"
        }
    )

    $mutationRejections = 0
    foreach ($case in $mutationCases) {
        $caseMarker = if ($case.Contains("marker")) {
            [string]$case.marker
        } else {
            $failureMarker
        }
        $receipt = Invoke-R23D64GodotWorker `
            -UserArguments ([string[]]$case.args) `
            -ExpectedExitCode 1 `
            -ExpectedMarker $caseMarker
        $physicalAcceptanceAuthority = if (
            $receipt.Contains("physical_acceptance_authority")
        ) {
            [bool]$receipt["physical_acceptance_authority"]
        } elseif (
            $receipt.Contains("claims") -and
            $receipt["claims"].Contains("physical_acceptance_authority")
        ) {
            [bool]$receipt["claims"]["physical_acceptance_authority"]
        } else {
            $true
        }
        Assert-R23D64GodotWorker (
            (-not $receipt.Contains("ok") -or -not [bool]$receipt["ok"]) -and
            [string]$receipt.failure_code -ceq [string]$case.code -and
            [int]$receipt.world_attempt_count -eq 0 -and
            [int]$receipt.world_build_count -eq 0 -and
            -not $physicalAcceptanceAuthority
        ) "R23D64 Godot worker mutation was not rejected: $($case.id)"
        $mutationRejections += 1
    }

    $routeOutput = @(
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File (Join-Path (
                $repoRoot
            ) "tests\test_qsdk_r23d64_godot_public_profile_physical_route.ps1") `
            -Godot $godotPath 2>&1
    )
    $routeExit = $LASTEXITCODE
    $routeText = $routeOutput -join [Environment]::NewLine
    Assert-R23D64GodotWorker (
        $routeExit -eq 0 -and
        $routeText.Contains(
            "QSDK_R23D64_GODOT_PUBLIC_PROFILE_ROUTE_PASS",
            [StringComparison]::Ordinal
        )
    ) "R23D64 Godot worker production-route dependency failed`n$routeText"

    Assert-R23D64GodotWorker (
        ($positiveCells -join "|") -ceq (
            "godot_jolt__s23171__selected_profile__reference_zero|" +
            "godot_jolt__s23171__selected_profile__positive_heading|" +
            "godot_jolt__s23171__selected_profile__negative_heading"
        ) -and
        $mutationRejections -eq 11
    ) "R23D64 Godot worker matrix or mutation cardinality changed"

    Write-Output (
        "QSDK_R23D64_GODOT_WORKER_ZERO_WORLD_PASS cells=3 " +
        "mutation_rejections=11 route_writes=8 route_readbacks=8 " +
        "models=0 worlds=0 physical=False turning=False qsdk_r23=False " +
        "equivalence=False release=False"
    )
}
finally {
    foreach ($name in $authorizationEnvironmentNames) {
        [Environment]::SetEnvironmentVariable(
            $name,
            $savedEnvironment[$name],
            [EnvironmentVariableTarget]::Process
        )
    }
}
