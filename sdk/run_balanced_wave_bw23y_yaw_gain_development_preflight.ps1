[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$godot = [System.IO.Path]::GetFullPath($Godot)
$policyId = "sporespore_balanced_wave_bw23y_b_v1"
$prefix = "BW23Y_YAW_GAIN_DEVELOPMENT_PROBE "

function Invoke-Bw23yGodotProbe {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][int]$ExpectedExitCode
    )

    $output = & $godot --headless --path $repoRoot `
        --script res://scripts/tools/probe_bw23y_yaw_gain_development.gd `
        -- @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne $ExpectedExitCode) {
        throw "BW23Y probe exit mismatch: expected $ExpectedExitCode, observed $exitCode.`n$($output -join [Environment]::NewLine)"
    }
    $receiptLine = @(
        $output |
            ForEach-Object { [string]$_ } |
            Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }
    ) | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($receiptLine)) {
        throw "BW23Y probe did not emit its receipt prefix."
    }
    return $receiptLine.Substring($prefix.Length) | ConvertFrom-Json -Depth 100
}

if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw "Pinned Godot executable is unavailable: $godot"
}

Push-Location $PSScriptRoot
try {
    # Godot's editor/headless host selects windows.debug from the .gdextension
    # manifest. Building only --release can therefore leave a stale DLL live.
    if (-not $SkipBuild) {
        & cargo build -p sporespore-godot-adapter
        if ($LASTEXITCODE -ne 0) {
            throw "Godot adapter debug build failed."
        }
    }

    $identityJson = & cargo run --quiet -p sporespore-locomotion-core `
        --example inspect_policy_profile -- $policyId
    if ($LASTEXITCODE -ne 0) {
        throw "BW23Y policy identity inspection failed."
    }
    $identity = $identityJson | ConvertFrom-Json -Depth 100
}
finally {
    Pop-Location
}

$negative = Invoke-Bw23yGodotProbe `
    -Arguments @("081", "25011", "preflight") `
    -ExpectedExitCode 1
$positive = Invoke-Bw23yGodotProbe `
    -Arguments @("081", "24011", "preflight") `
    -ExpectedExitCode 0
$authorityStart = $positive.summary.selected_policy_full_authority_start

$checks = [ordered]@{
    identity_ok = [bool]$identity.ok
    identity_schema = [string]$identity.schema_version -ceq "sporespore_policy_profile_inspection_receipt_v1"
    identity_policy = [string]$identity.policy_id -ceq $policyId
    profile_policy = [string]$identity.profile.policy_id -ceq $policyId
    yaw_gain = [double]$identity.profile.yaw_error_stride_gain_per_rad -eq 1.0
    profile_digest = [string]$identity.profile_sha256 -match '^sha256:[0-9a-f]{64}$'
    identity_zero_world = [int]$identity.actual_world_build_count -eq 0
    identity_no_physics = -not [bool]$identity.physics_state_modified
    identity_no_outcome = -not [bool]$identity.locomotion_outcome_exposed
    identity_no_authority = -not [bool]$identity.physical_acceptance_authority
    negative_rejected = -not [bool]$negative.ok
    negative_code = [string]$negative.failure_code -ceq "BW23Y_PROBE_REJECTS_UNEXPOSED_VALUE_OR_SEED"
    negative_zero_world = [int]$negative.world_build_count -eq 0
    positive_ok = [bool]$positive.ok
    positive_policy = [string]$positive.controller_policy_id -ceq $policyId
    positive_scope = [string]$positive.summary.authority_scope -ceq "post_settle_full"
    positive_entrypoint = [bool]$positive.summary.entrypoint_control_flow_complete
    positive_start = [bool]$positive.summary.selected_policy_full_authority_start_passed
    start_policy = [string]$authorityStart.controller_policy_id -ceq $policyId
    start_scope = [string]$authorityStart.authority_scope -ceq "post_settle_full"
    start_stability = [string]$authorityStart.stability_policy_id -ceq "sporespore_scheduled_load_transfer_bw13p_a_v3"
    start_scale = [double]$authorityStart.global_requested_correction_scale -eq 0.5
    start_plan = [bool]$authorityStart.sdk_execution_mode_plan_passed
    start_boundary = [bool]$authorityStart.declared_policy_runtime_boundary_preflight_passed
    positive_zero_world = [int]$positive.actual_world_build_count -eq 0
    positive_zero_insertions = [int]$positive.scene_tree_insertion_count -eq 0
    positive_no_physics = -not [bool]$positive.physics_state_modified
    positive_no_outcome = -not [bool]$positive.locomotion_outcome_exposed
    positive_no_authority = -not [bool]$positive.physical_acceptance_authority
}
$failedChecks = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value })
$exact = $failedChecks.Count -eq 0
if (-not $exact) {
    [ordered]@{
        identity_ok = $identity.ok
        identity_policy_id = $identity.policy_id
        profile_policy_id = $identity.profile.policy_id
        profile_sha256 = $identity.profile_sha256
        yaw_gain = $identity.profile.yaw_error_stride_gain_per_rad
        negative_ok = $negative.ok
        negative_failure_code = $negative.failure_code
        negative_world_build_count = $negative.world_build_count
        failed_checks = @($failedChecks | ForEach-Object { $_.Key })
        positive = [ordered]@{
            ok = $positive.ok
            controller_policy_id = $positive.controller_policy_id
            actual_world_build_count = $positive.actual_world_build_count
            scene_tree_insertion_count = $positive.scene_tree_insertion_count
            physics_state_modified = $positive.physics_state_modified
            locomotion_outcome_exposed = $positive.locomotion_outcome_exposed
            physical_acceptance_authority = $positive.physical_acceptance_authority
            entrypoint_control_flow_complete = $positive.summary.entrypoint_control_flow_complete
            selected_policy_full_authority_start_passed = $positive.summary.selected_policy_full_authority_start_passed
            authority_start_ok = $authorityStart.ok
            authority_scope = $authorityStart.authority_scope
            stability_policy_id = $authorityStart.stability_policy_id
            global_requested_correction_scale = $authorityStart.global_requested_correction_scale
            sdk_execution_mode_plan_passed = $authorityStart.sdk_execution_mode_plan_passed
            declared_policy_runtime_boundary_preflight_passed = $authorityStart.declared_policy_runtime_boundary_preflight_passed
        }
    } | ConvertTo-Json -Depth 5 | Write-Error
    throw "BW23Y development preflight receipt mismatch."
}

Write-Output (
    "BW23Y_YAW_GAIN_DEVELOPMENT_PREFLIGHT_PASS " +
    "profile_sha256=$($identity.profile_sha256) " +
    "yaw_gain=$($identity.profile.yaw_error_stride_gain_per_rad) " +
    "unexposed_canary=True authority_scope=$($positive.summary.authority_scope) " +
    "worlds=0 outcomes_exposed=False physical_authority=False"
)
