#requires -Version 7.0

$script:Gjpt1BaseRunnerRelativePath =
    "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$script:Gjpt1GeneratedRunnerRelativePath =
    "sdk\target\gjpt1\physical_wave_gait_quadruped_phase_timing.gd"
$script:Gjpt1BaseRunnerRawSha256 =
    "79795d3c76191722b4fb35ef7ee4b4fccd297a01b6a528278a913d5cbfa462ca"

function Get-Gjpt1RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Replace-Gjpt1ExactOnce {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Anchor,
        [Parameter(Mandatory)][string]$Replacement,
        [Parameter(Mandatory)][string]$Label
    )
    $first = $Text.IndexOf($Anchor, [System.StringComparison]::Ordinal)
    if ($first -lt 0) { throw "GJPT1 transformation anchor is missing: $Label" }
    $second = $Text.IndexOf(
        $Anchor,
        $first + $Anchor.Length,
        [System.StringComparison]::Ordinal
    )
    if ($second -ge 0) { throw "GJPT1 transformation anchor is ambiguous: $Label" }
    return $Text.Substring(0, $first) + $Replacement +
        $Text.Substring($first + $Anchor.Length)
}

function Get-Gjpt1InstrumentedRunnerSource {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)

    $repo = [System.IO.Path]::GetFullPath($RepoRoot)
    $basePath = Join-Path $repo $script:Gjpt1BaseRunnerRelativePath
    if (-not (Test-Path -LiteralPath $basePath -PathType Leaf)) {
        throw "GJPT1 base runner is missing: $basePath"
    }
    if ((Get-Gjpt1RawSha256 $basePath) -cne $script:Gjpt1BaseRunnerRawSha256) {
        throw "GJPT1 frozen base-runner bytes changed: $basePath"
    }
    $source = [System.IO.File]::ReadAllText($basePath).
        Replace("`r`n", "`n").Replace("`r", "`n")
    $join = { param([string[]]$Lines) return ($Lines -join "`n") }

    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor "class_name LabPhysicalWaveGaitQuadruped`n" `
        -Replacement "class_name LabPhysicalWaveGaitQuadrupedGjpt1PhaseTiming`n" `
        -Label "distinct class identity"

    $runEntry = & $join @(
        ") -> Dictionary:"
        "`tvar _gjpt1_run_start_usec := Time.get_ticks_usec()"
        "`tif contact_clearance_assist_rad < 0.0:"
    )
    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor (") -> Dictionary:`n`tif contact_clearance_assist_rad < 0.0:") `
        -Replacement $runEntry `
        -Label "run start clock"

    $loopState = & $join @(
        "`t`tgated_gait_tick_by_limb[limb_id] = 0"
        "`t`tevidence_start_gait_tick_by_limb[limb_id] = -1"
        "`t`tevidence_end_gait_tick_by_limb[limb_id] = -1"
        "`t`tcurrent_contact_gate_hold_ticks_by_limb[limb_id] = 0"
        "`t`tcurrent_contact_gate_transition_dwell_ticks_by_limb[limb_id] = 0"
        "`t`tcontact_gate_hold_tick_count_by_limb[limb_id] = 0"
        "`t`tcontact_gate_release_hold_tick_count_by_limb[limb_id] = 0"
        "`t`tcontact_gate_recontact_hold_tick_count_by_limb[limb_id] = 0"
        "`t`tcontact_gate_timeout_count_by_limb[limb_id] = 0"
        "`t`tcontact_gate_timeout_receipts_by_limb[limb_id] = []"
        "`t`tcontact_gate_phase_sync_hold_tick_count_by_limb[limb_id] = 0"
        "`tvar _gjpt1_pre_physics_active_usec := 0"
        "`tvar _gjpt1_native_boundary_usec := 0"
        "`tvar _gjpt1_physics_frame_wait_usec := 0"
        "`tvar _gjpt1_post_physics_observation_evidence_usec := 0"
        "`tvar _gjpt1_instrumented_tick_count := 0"
        "`tvar _gjpt1_tick_active_start_usec := 0"
        "`tvar _gjpt1_post_physics_start_usec := 0"
        "`tfor tick in range(maximum_total_ticks):"
        "`t`t_gjpt1_tick_active_start_usec = Time.get_ticks_usec()"
    )
    $loopAnchor = & $join @(
        "`t`tgated_gait_tick_by_limb[limb_id] = 0"
        "`t`tevidence_start_gait_tick_by_limb[limb_id] = -1"
        "`t`tevidence_end_gait_tick_by_limb[limb_id] = -1"
        "`t`tcurrent_contact_gate_hold_ticks_by_limb[limb_id] = 0"
        "`t`tcurrent_contact_gate_transition_dwell_ticks_by_limb[limb_id] = 0"
        "`t`tcontact_gate_hold_tick_count_by_limb[limb_id] = 0"
        "`t`tcontact_gate_release_hold_tick_count_by_limb[limb_id] = 0"
        "`t`tcontact_gate_recontact_hold_tick_count_by_limb[limb_id] = 0"
        "`t`tcontact_gate_timeout_count_by_limb[limb_id] = 0"
        "`t`tcontact_gate_timeout_receipts_by_limb[limb_id] = []"
        "`t`tcontact_gate_phase_sync_hold_tick_count_by_limb[limb_id] = 0"
        "`tfor tick in range(maximum_total_ticks):"
    )
    $source = Replace-Gjpt1ExactOnce -Text $source -Anchor $loopAnchor `
        -Replacement $loopState -Label "main-loop phase state"

    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor "`t`t`tsdk_adapter_start_result = (`n" `
        -Replacement (& $join @(
            "`t`t`tvar _gjpt1_native_start_usec := Time.get_ticks_usec()"
            "`t`t`tsdk_adapter_start_result = ("
        )) `
        -Label "native start begin"
    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor (& $join @(
            "`t`t`t)"
            "`t`tvar sdk_adapter_sample_result: Dictionary = {}"
        )) `
        -Replacement (& $join @(
            "`t`t`t)"
            "`t`t`t_gjpt1_native_boundary_usec += ("
            "`t`t`t`tTime.get_ticks_usec() - _gjpt1_native_start_usec"
            "`t`t`t)"
            "`t`tvar sdk_adapter_sample_result: Dictionary = {}"
        )) `
        -Label "native start end"

    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor "`t`t`tvar sdk_adapter_step_result: Dictionary = (`n" `
        -Replacement (& $join @(
            "`t`t`tvar _gjpt1_native_step_start_usec := Time.get_ticks_usec()"
            "`t`t`tvar sdk_adapter_step_result: Dictionary = ("
        )) `
        -Label "native step begin"
    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor (& $join @(
            "`t`t`t)"
            "`t`t`tif sdk_authority_enabled:"
        )) `
        -Replacement (& $join @(
            "`t`t`t)"
            "`t`t`t_gjpt1_native_boundary_usec += ("
            "`t`t`t`tTime.get_ticks_usec() - _gjpt1_native_step_start_usec"
            "`t`t`t)"
            "`t`t`tif sdk_authority_enabled:"
        )) `
        -Label "native step end"

    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor (& $join @(
            "`t`tawait tree.physics_frame"
            "`t`texecuted_ticks = tick + 1"
        )) `
        -Replacement (& $join @(
            "`t`t_gjpt1_pre_physics_active_usec += ("
            "`t`t`tTime.get_ticks_usec() - _gjpt1_tick_active_start_usec"
            "`t`t)"
            "`t`tvar _gjpt1_physics_wait_start_usec := Time.get_ticks_usec()"
            "`t`tawait tree.physics_frame"
            "`t`t_gjpt1_physics_frame_wait_usec += ("
            "`t`t`tTime.get_ticks_usec() - _gjpt1_physics_wait_start_usec"
            "`t`t)"
            "`t`t_gjpt1_post_physics_start_usec = Time.get_ticks_usec()"
            "`t`texecuted_ticks = tick + 1"
        )) `
        -Label "physics-frame wait"

    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor "`t`tif not authority_horizon_enabled and run_end_tick >= 0 and tick + 1 >= run_end_tick:`n" `
        -Replacement (& $join @(
            "`t`t_gjpt1_post_physics_observation_evidence_usec += ("
            "`t`t`tTime.get_ticks_usec() - _gjpt1_post_physics_start_usec"
            "`t`t)"
            "`t`t_gjpt1_instrumented_tick_count += 1"
            "`t`tif not authority_horizon_enabled and run_end_tick >= 0 and tick + 1 >= run_end_tick:"
        )) `
        -Label "post-physics phase end"

    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor (& $join @(
            "`tif dynamic_support_diagnostic_enabled:"
            "`t`tsummary[`"dynamic_support_diagnostic_enabled`"] = true"
        )) `
        -Replacement (& $join @(
            "`tvar _gjpt1_before_cleanup_usec := Time.get_ticks_usec()"
            "`tsummary[`"gjpt1_phase_timing`"] = {"
            "`t`t`"schema_version`": `"sporespore_godot_jolt_phase_timing_inner_v1`","
            "`t`t`"instrumented_tick_count`": _gjpt1_instrumented_tick_count,"
            "`t`t`"pre_physics_active_inclusive_boundary_usec`": _gjpt1_pre_physics_active_usec,"
            "`t`t`"native_boundary_usec`": _gjpt1_native_boundary_usec,"
            "`t`t`"pre_physics_active_exclusive_boundary_usec`":"
            "`t`tmaxi(_gjpt1_pre_physics_active_usec - _gjpt1_native_boundary_usec, 0),"
            "`t`t`"physics_frame_wait_usec`": _gjpt1_physics_frame_wait_usec,"
            "`t`t`"post_physics_observation_evidence_usec`":"
            "`t`t_gjpt1_post_physics_observation_evidence_usec,"
            "`t`t`"world_runner_before_cleanup_usec`":"
            "`t`t_gjpt1_before_cleanup_usec - _gjpt1_run_start_usec,"
            "`t}"
            "`tif dynamic_support_diagnostic_enabled:"
            "`t`tsummary[`"dynamic_support_diagnostic_enabled`"] = true"
        )) `
        -Label "inner timing receipt"

    $source = Replace-Gjpt1ExactOnce -Text $source `
        -Anchor (& $join @(
            "`tEngine.physics_ticks_per_second = original_hz"
            "`treturn summary"
        )) `
        -Replacement (& $join @(
            "`tEngine.physics_ticks_per_second = original_hz"
            "`tvar _gjpt1_world_runner_total_usec := ("
            "`t`tTime.get_ticks_usec() - _gjpt1_run_start_usec"
            "`t)"
            "`tvar _gjpt1_accounted_usec := ("
            "`t`t_gjpt1_pre_physics_active_usec"
            "`t`t+ _gjpt1_physics_frame_wait_usec"
            "`t`t+ _gjpt1_post_physics_observation_evidence_usec"
            "`t)"
            "`tvar _gjpt1_phase_receipt: Dictionary = summary[`"gjpt1_phase_timing`"]"
            "`t_gjpt1_phase_receipt[`"world_runner_total_usec`"] = _gjpt1_world_runner_total_usec"
            "`t_gjpt1_phase_receipt[`"setup_summary_cleanup_residual_usec`"] = ("
            "`t`tmaxi(_gjpt1_world_runner_total_usec - _gjpt1_accounted_usec, 0)"
            "`t)"
            "`treturn summary"
        )) `
        -Label "world-runner total"

    return $source + "`n"
}

function New-Gjpt1InstrumentedRunner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$OutputPath = ""
    )
    $repo = [System.IO.Path]::GetFullPath($RepoRoot)
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $repo $script:Gjpt1GeneratedRunnerRelativePath
    }
    $resolved = [System.IO.Path]::GetFullPath($OutputPath)
    $expectedPrefix = [System.IO.Path]::GetFullPath(
        (Join-Path $repo "sdk\target\gjpt1")
    ).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith(
        $expectedPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "GJPT1 generated runner must remain under sdk/target/gjpt1"
    }
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    [System.IO.File]::WriteAllText(
        $resolved,
        (Get-Gjpt1InstrumentedRunnerSource -RepoRoot $repo),
        [System.Text.UTF8Encoding]::new($false)
    )
    return [ordered]@{
        base_path = Join-Path $repo $script:Gjpt1BaseRunnerRelativePath
        base_raw_sha256 = "sha256:$script:Gjpt1BaseRunnerRawSha256"
        generated_path = $resolved
        generated_raw_sha256 = "sha256:$(Get-Gjpt1RawSha256 $resolved)"
        generated_byte_length = (Get-Item -LiteralPath $resolved).Length
        physical_worlds = 0
        physical_acceptance_authority = $false
    }
}
