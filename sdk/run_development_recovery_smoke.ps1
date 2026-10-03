#requires -Version 7.5
<# Default is the complete applicable zero-world safety gate. -RunSmoke adds
two fresh diagnostic children, never an official campaign or acceptance run. #>
[CmdletBinding()]
param([switch]$RunSmoke, [switch]$ProfileSteps, [switch]$ReuseContextChecks, [switch]$ObserveProneDeadline,
      [switch]$ObserveMeasuredProneEntry, [switch]$ObserveRearwardFold, [switch]$ObserveRateLimitedRecovery,
      [string]$CandidateProfile, [switch]$SingleKick, [string]$R10KPositivePair, [string]$R10LPositivePair, [string]$R10MPositivePair, [string]$R10NPositivePair, [string]$R10OPositivePair, [string]$R10QPositivePair, [Nullable[int]]$R10QDiagnosticSeed, [string]$R10RPrerequisite, [Nullable[int]]$R10RDiagnosticSeed, [string]$R10SPrerequisite, [Nullable[int]]$R10SDiagnosticSeed, [string]$R10TPrerequisite, [Nullable[int]]$R10TDiagnosticSeed, [string]$R10VPrerequisite, [Nullable[int]]$R10VDiagnosticSeed, [string]$R10VHostRequest, [string]$R10UPrerequisite, [Nullable[int]]$R10UDiagnosticSeed, [switch]$Library, [switch]$R10WCampaignLibrary, [switch]$R10XCampaignLibrary)
$executeSmoke = $RunSmoke.IsPresent
$profileStepsRequested = $ProfileSteps.IsPresent
$reuseContextChecksRequested = $ReuseContextChecks.IsPresent
$observeProneDeadlineRequested = $ObserveProneDeadline.IsPresent
$observeMeasuredProneEntryRequested = $ObserveMeasuredProneEntry.IsPresent
$observeRearwardFoldRequested = $ObserveRearwardFold.IsPresent
$observeRateLimitedRecoveryRequested = $ObserveRateLimitedRecovery.IsPresent
$smokeLibraryRequested = $Library.IsPresent
$r10xCampaignLibraryRequested = $R10XCampaignLibrary.IsPresent
if ($r10xCampaignLibraryRequested -and (-not $Library -or $RunSmoke -or $SingleKick -or $R10WCampaignLibrary)) { throw 'R10X_CAMPAIGN_LIBRARY_ONLY' }
$r10wCampaignLibraryRequested = $R10WCampaignLibrary.IsPresent
if ($r10wCampaignLibraryRequested -and (-not $Library -or $RunSmoke -or $SingleKick)) { throw 'R10W_CAMPAIGN_LIBRARY_ONLY' }
$candidatePathRequested = $CandidateProfile
$singleKickRequested = $SingleKick.IsPresent
$r10kPositivePairRequested = $R10KPositivePair
$r10kDevelopmentContext = $null
$r10vHostRequestRequested = $R10VHostRequest
$script:R10VHostContext = $null
$r10vDevelopmentContext = $null
$r10uDevelopmentContext = $null
$r10abSelected = $false
$r10apSelected = $false
$r10amSelected = $false
$r10ajSelected = $false
$r10apDevelopmentContext = $null
$r10amDevelopmentContext = $null
$r10ajDevelopmentContext = $null
$r10aiSelected = $false
$r10aiDevelopmentContext = $null
$r10agSelected = $false
$r10agDevelopmentContext = $null
$r10afSelected = $false
$r10afDevelopmentContext = $null
$r10aeSelected = $false
$r10aeDevelopmentContext = $null
$r10adSelected = $false
$r10adDevelopmentContext = $null
$r10acSelected = $false
$r10acDevelopmentContext = $null
$r10aaSelected = $false
$r10zSelected = $false
$r10abDevelopmentContext = $null
$r10aaDevelopmentContext = $null
$r10zDevelopmentContext = $null
$r10ySelected = $false
$r10yDevelopmentContext = $null
$r10vSelected = $false
$r10uSelected = $false
$r10vPrerequisiteRequested = $R10VPrerequisite
$r10uPrerequisiteRequested = $R10UPrerequisite
$r10vDiagnosticSeedRequested = $R10VDiagnosticSeed
$r10uDiagnosticSeedRequested = $R10UDiagnosticSeed
$r10tDevelopmentContext = $null
$r10tPrerequisiteRequested = $R10TPrerequisite
$r10tDiagnosticSeedRequested = $R10TDiagnosticSeed
$r10tSelected = $false
$r10sDevelopmentContext = $null
$r10sPrerequisiteRequested = $R10SPrerequisite
$r10sDiagnosticSeedRequested = $R10SDiagnosticSeed
$r10sSelected = $false
$r10rDevelopmentContext = $null
$r10rPrerequisiteRequested = $R10RPrerequisite
$r10rDiagnosticSeedRequested = $R10RDiagnosticSeed
$r10rSelected = $false
$r10qDevelopmentContext = $null
$r10qPositivePairRequested = $R10QPositivePair
$r10qDiagnosticSeedRequested = $R10QDiagnosticSeed
$r10qSelected = $false
$r10oDevelopmentContext = $null
$r10nDevelopmentContext = $null
$r10mDevelopmentContext = $null
$r10lDevelopmentContext = $null
$r10oPositivePairRequested = $R10OPositivePair
$r10nPositivePairRequested = $R10NPositivePair
$r10mPositivePairRequested = $R10MPositivePair
$r10lPositivePairRequested = $R10LPositivePair
$r10oSelected = $false
$r10nSelected = $false
$r10mSelected = $false
$r10lSelected = $false
$r10kSelected = $false
if (($r10vPrerequisiteRequested -or $null -ne $r10vDiagnosticSeedRequested) -and -not $candidatePathRequested) { throw 'R10V_OPTIONS_REQUIRE_CANDIDATE_PROFILE' }
if (($r10uPrerequisiteRequested -or $null -ne $r10uDiagnosticSeedRequested) -and -not $candidatePathRequested) { throw 'R10U_OPTIONS_REQUIRE_CANDIDATE_PROFILE' }
if (($r10tPrerequisiteRequested -or $null -ne $r10tDiagnosticSeedRequested) -and -not $candidatePathRequested) { throw 'R10T_OPTIONS_REQUIRE_CANDIDATE_PROFILE' }
if (($r10sPrerequisiteRequested -or $null -ne $r10sDiagnosticSeedRequested) -and -not $candidatePathRequested) { throw 'R10S_OPTIONS_REQUIRE_CANDIDATE_PROFILE' }
if (($r10rPrerequisiteRequested -or $null -ne $r10rDiagnosticSeedRequested) -and -not $candidatePathRequested) { throw 'R10R_OPTIONS_REQUIRE_CANDIDATE_PROFILE' }
if (($r10qPositivePairRequested -or $null -ne $r10qDiagnosticSeedRequested) -and -not $candidatePathRequested) { throw 'R10Q_OPTIONS_REQUIRE_CANDIDATE_PROFILE' }
if ($r10oPositivePairRequested -and -not $candidatePathRequested) { throw 'R10O_PREREQUISITE_REQUIRES_CANDIDATE_PROFILE' }
if ($r10nPositivePairRequested -and -not $candidatePathRequested) { throw 'R10N_PREREQUISITE_REQUIRES_CANDIDATE_PROFILE' }
if ($r10mPositivePairRequested -and -not $candidatePathRequested) { throw 'R10M_PREREQUISITE_REQUIRES_CANDIDATE_PROFILE' }
if ($r10lPositivePairRequested -and -not $candidatePathRequested) { throw 'R10L_PREREQUISITE_REQUIRES_CANDIDATE_PROFILE' }
if ($r10kPositivePairRequested -and -not $candidatePathRequested) { throw 'R10K_PREREQUISITE_REQUIRES_CANDIDATE_PROFILE' }
if ($candidatePathRequested -and -not $reuseContextChecksRequested) { throw 'SMOKE_CANDIDATE_REQUIRES_CONTEXT_CACHE' }
if ($candidatePathRequested -and ($observeMeasuredProneEntryRequested -or $observeProneDeadlineRequested -or $observeRearwardFoldRequested -or $observeRateLimitedRecoveryRequested)) { throw 'SMOKE_DIAGNOSTIC_SCHEDULES_EXCLUSIVE' }
if ($singleKickRequested -and -not $candidatePathRequested) { throw 'SMOKE_SINGLE_KICK_REQUIRES_CANDIDATE_PROFILE' }
if ($Library -and $RunSmoke) { throw 'SMOKE_LIBRARY_CANNOT_RUN' }
if ($reuseContextChecksRequested -and -not $profileStepsRequested) { throw 'SMOKE_CONTEXT_CACHE_REQUIRES_PROFILE_STEPS' }
if ($observeProneDeadlineRequested -and -not $reuseContextChecksRequested) { throw 'SMOKE_PRONE_DEADLINE_REQUIRES_CONTEXT_CACHE' }
if ($observeMeasuredProneEntryRequested -and -not $reuseContextChecksRequested) { throw 'SMOKE_MEASURED_ENTRY_REQUIRES_CONTEXT_CACHE' }
if ($observeMeasuredProneEntryRequested -and $observeProneDeadlineRequested) { throw 'SMOKE_DIAGNOSTIC_SCHEDULES_EXCLUSIVE' }
if ($observeRearwardFoldRequested -and -not $reuseContextChecksRequested) { throw 'SMOKE_REARWARD_FOLD_REQUIRES_CONTEXT_CACHE' }
if ($observeRearwardFoldRequested -and ($observeMeasuredProneEntryRequested -or $observeProneDeadlineRequested)) { throw 'SMOKE_DIAGNOSTIC_SCHEDULES_EXCLUSIVE' }
if ($observeRateLimitedRecoveryRequested -and -not $reuseContextChecksRequested) { throw 'SMOKE_RATE_LIMITED_RECOVERY_REQUIRES_CONTEXT_CACHE' }
if ($observeRateLimitedRecoveryRequested -and ($observeMeasuredProneEntryRequested -or $observeProneDeadlineRequested -or $observeRearwardFoldRequested)) { throw 'SMOKE_DIAGNOSTIC_SCHEDULES_EXCLUSIVE' }
. (Join-Path $PSScriptRoot 'run_qsdk_r10f_continuous_passive_recovery.ps1') -DevelopmentLibrary
. (Join-Path $PSScriptRoot 'run_development_interfaces.ps1') -Library
$TimeoutSeconds = 600
$stages += @(
    @{id='smoke_native_safety';pattern='test_development_recovery_smoke.py';tests=3},
    @{id='smoke_reader_controls';pattern='test_development_recovery_smoke_reader.py';tests=3},
    @{id='step_cost_profile_controls';pattern='test_development_step_cost_profile.py';tests=4}
)
$script:WorkerResource = 'res://sdk/adapters/godot/gdscript/development_recovery_smoke_worker_v1.gd'
if ($profileStepsRequested) {
    $script:WorkerResource = 'res://sdk/adapters/godot/gdscript/development_profiled_recovery_smoke_worker_v1.gd'
}
if ($reuseContextChecksRequested) {
    $script:WorkerResource = 'res://sdk/adapters/godot/gdscript/development_cached_recovery_smoke_worker_v1.gd'
    $stages += @(
        @{id='context_cache_exact_inputs';pattern='test_development_exact_context_cache.py';tests=3},
        @{id='context_cache_integration';pattern='test_development_context_cache_integration.py';tests=5},
        @{id='prone_deadline_schedule';pattern='test_development_recovery_prone_deadline.py';tests=5}
    )
}
$script:RawSchema = 'sporespore_sdk1_development_recovery_smoke_child_v1'
$script:RawMarker = 'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '
$script:WorkId = 'SDK1-GODOT-RECOVERY-DEVELOPMENT-SMOKE-V1'
if ($observeMeasuredProneEntryRequested) {
    $TimeoutSeconds = 1500
    $script:WorkerResource = 'res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd'
    $script:RawSchema = 'sporespore_development_measured_prone_smoke_child_v1'
    $script:WorkId = 'SDK1-GODOT-MEASURED-PRONE-ENTRY-SMOKE-V1'
    $stages += @(
        @{id='passive_entry_boundaries';pattern='test_development_passive_entry_*.py';tests=16},
        @{id='measured_entry_profile';pattern='test_development_measured_entry_profile.py';tests=5}
    )
}
if ($observeRearwardFoldRequested) {
    $rearwardProfile = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development_rearward_fold_profile_v1.json') -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $TimeoutSeconds = 1500
    $script:WorkerResource = $rearwardProfile.worker_selection.worker
    $script:RawSchema = $rearwardProfile.worker_selection.report_schema
    $script:WorkId = $rearwardProfile.worker_selection.work_id
    # The old source-bound DLL gate remains closed after the Rust change.
    # Re-exercise its affected coverage on the explicitly selected V7 superset.
    $stages += @(
        @{id='rearward_fold_runtime_worker';pattern='test_development_rearward_fold_runtime.py';tests=7},
        @{id='rearward_fold_transport';pattern='test_development_rearward_fold_transport.py';tests=7},
        @{id='rearward_fold_reader';pattern='test_development_rearward_fold_replay.py';tests=8},
        @{id='rearward_fold_profile';pattern='test_development_rearward_fold_profile.py';tests=5}
    )
}

if ($observeRateLimitedRecoveryRequested) {
    $rateLimitedProfile = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development_rate_limited_recovery_profile_v1.json') -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $TimeoutSeconds = 1500
    $script:WorkerResource = $rateLimitedProfile.worker_selection.worker
    $script:RawSchema = $rateLimitedProfile.worker_selection.report_schema
    $script:WorkId = $rateLimitedProfile.worker_selection.work_id
    # Re-exercise affected coverage on V8, with V6 and V7 compatibility checks.
    # The old source-bound runtime keys remain invalidated, never waived.
    $stages += @(
        @{id='rate_limited_runtime_worker';pattern='test_development_rate_limited_recovery_runtime.py';tests=7},
        @{id='rate_limited_transport';pattern='test_development_rate_limited_recovery_transport.py';tests=7},
        @{id='rate_limited_reader';pattern='test_development_rate_limited_recovery_replay.py';tests=8},
        @{id='rate_limited_profile';pattern='test_development_rate_limited_recovery_profile.py';tests=5}
    )
}

if ($candidatePathRequested) {
    $candidateOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/development_recovery_candidate.py') $candidatePathRequested)
    if ($LASTEXITCODE -ne 0 -or $candidateOutput.Count -ne 1) { throw 'SMOKE_CANDIDATE_PROFILE_INVALID' }
    $candidateSelection = $candidateOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
    $candidatePathRequested = $candidateSelection.candidate_profile.resource.Replace('res://', '')
    $TimeoutSeconds = 1500
    $script:WorkerResource = $candidateSelection.worker_selection.worker
    $script:RawSchema = $candidateSelection.worker_selection.report_schema
    $script:WorkId = $candidateSelection.worker_selection.work_id
    $r10xCandidate = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10x-v56-campaign-v1.json'
    if ($r10xCandidate -ne $r10xCampaignLibraryRequested) { throw 'R10X_REQUIRES_OWN_CAMPAIGN_LIBRARY' }
    $r10wCandidate = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10w-v56-campaign-v1.json'
    if ($r10wCandidate -ne $r10wCampaignLibraryRequested) { throw 'R10W_REQUIRES_OWN_CAMPAIGN_LIBRARY' }
    $r10apSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10ap-progressive-headroom-v1.json'
    $r10amSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10am-support-anchored-v1.json'
    $r10ajSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10aj-hip-recenter-v1.json'
    $r10aiSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10ai-concurrent-load-rise-v1.json'
    $r10agSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10ag-detection-frame-load-seeking-v1.json'
    $r10afSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10af-detection-frame-recovery-v1.json'
    $r10aeSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10ae-contact-frame-diagnostic-v1.json'
    $r10adSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10ad-contact-frame-diagnostic-v1.json'
    $r10acSelected = $candidateSelection.candidate_profile.resource -ceq 'res://sdk/development/recovery_candidates/r10ac-contact-frame-diagnostic-v2.json'
    $r10abSelected = -not $r10apSelected -and -not $r10amSelected -and -not $r10ajSelected -and -not $r10aiSelected -and -not $r10agSelected -and -not $r10afSelected -and -not $r10aeSelected -and -not $r10adSelected -and -not $r10acSelected -and $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -ceq 'r10ab_partial_downward_rise_route_v1'
    $r10aaSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -ceq 'r10aa_partial_load_seeking_route_v1'
    $r10zSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -ceq 'r10z_partial_pose_geometry_route_v1'
    $r10ySelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -ceq 'r10y_partial_direct_neutral_route_v1'
    $r10vSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10v_v56_post_recovery_hold_route_v1' -and -not $r10wCampaignLibraryRequested -and -not $r10xCampaignLibraryRequested
    $r10uSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10u_v56_post_recovery_hold_route_v1'
    $r10tSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10t_v56_post_recovery_hold_route_v1'
    if (($r10vPrerequisiteRequested -or $null -ne $r10vDiagnosticSeedRequested) -and -not $r10vSelected) { throw 'R10V_OPTIONS_REQUIRE_R10V_ROUTE' }
    if (($r10uPrerequisiteRequested -or $null -ne $r10uDiagnosticSeedRequested) -and -not $r10uSelected) { throw 'R10U_OPTIONS_REQUIRE_R10U_ROUTE' }
    if (($r10tPrerequisiteRequested -or $null -ne $r10tDiagnosticSeedRequested) -and -not $r10tSelected) { throw 'R10T_OPTIONS_REQUIRE_R10T_ROUTE' }
    $r10sSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10s_v56_upright_recovery_route_v1'
    if (($r10sPrerequisiteRequested -or $null -ne $r10sDiagnosticSeedRequested) -and -not $r10sSelected) { throw 'R10S_OPTIONS_REQUIRE_R10S_ROUTE' }
    $r10rSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10r_v55_upright_recovery_route_v1'
    if (($r10rPrerequisiteRequested -or $null -ne $r10rDiagnosticSeedRequested) -and -not $r10rSelected) { throw 'R10R_OPTIONS_REQUIRE_R10R_ROUTE' }
    $r10qSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10q_v55_upright_recovery_route_v1'
    if (($r10qPositivePairRequested -or $null -ne $r10qDiagnosticSeedRequested) -and -not $r10qSelected) { throw 'R10Q_OPTIONS_REQUIRE_R10Q_ROUTE' }
    $r10kSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10k_v51_partial_fall_recovery_route_v1'
    $r10oSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10o_v55_partial_fall_recovery_route_v1'
    $r10nSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10n_v54_partial_fall_recovery_route_v1'
    $r10mSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10m_v53_partial_fall_recovery_route_v1'
    $r10lSelected = $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10l_v52_partial_fall_recovery_route_v1'
    if ($r10oPositivePairRequested -and -not $r10oSelected) { throw 'R10O_PREREQUISITE_REQUIRES_R10O_ROUTE' }
    if ($r10nPositivePairRequested -and -not $r10nSelected) { throw 'R10N_PREREQUISITE_REQUIRES_R10N_ROUTE' }
    if ($r10mPositivePairRequested -and -not $r10mSelected) { throw 'R10M_PREREQUISITE_REQUIRES_R10M_ROUTE' }
    if ($r10lPositivePairRequested -and -not $r10lSelected) { throw 'R10L_PREREQUISITE_REQUIRES_R10L_ROUTE' }
    if ($r10kPositivePairRequested -and -not $r10kSelected) { throw 'R10K_PREREQUISITE_REQUIRES_R10K_ROUTE' }
    if ($r10apSelected) {
        if (-not $singleKickRequested) { throw 'R10AP_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10ap_host_runtime.ps1')
        $Godot = (Get-R10apExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ap_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AP_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10apDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10apDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10apDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10apDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AP coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10apContractPath = Join-Path $PSScriptRoot 'development/r10ap_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10apContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ap_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AP_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10apStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10apStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    }
    elseif ($r10amSelected) {
        if (-not $singleKickRequested) { throw 'R10AM_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10am_host_runtime.ps1')
        $Godot = (Get-R10amExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10am_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AM_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10amDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10amDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10amDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10amDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AM coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10amContractPath = Join-Path $PSScriptRoot 'development/r10am_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10amContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10am_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AM_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10amStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10amStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    }
    elseif ($r10ajSelected) {
        if (-not $singleKickRequested) { throw 'R10AJ_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10aj_host_runtime.ps1')
        $Godot = (Get-R10ajExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aj_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AJ_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10ajDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10ajDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10ajDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10ajDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AJ coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10ajContractPath = Join-Path $PSScriptRoot 'development/r10aj_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10ajContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aj_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AJ_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10ajStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10ajStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    }
    elseif ($r10aiSelected) {
        if (-not $singleKickRequested) { throw 'R10AI_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10ai_host_runtime.ps1')
        $Godot = (Get-R10aiExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ai_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AI_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10aiDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10aiDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10aiDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10aiDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AI coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10aiContractPath = Join-Path $PSScriptRoot 'development/r10ai_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10aiContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ai_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AI_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10aiStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10aiStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10agSelected) {
        if (-not $singleKickRequested) { throw 'R10AG_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10ag_host_runtime.ps1')
        $Godot = (Get-R10agExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ag_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AG_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10agDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10agDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10agDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10agDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AG coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10agContractPath = Join-Path $PSScriptRoot 'development/r10ag_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10agContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ag_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AG_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10agStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10agStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10afSelected) {
        if (-not $singleKickRequested) { throw 'R10AF_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10af_host_runtime.ps1')
        $Godot = (Get-R10afExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10af_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AF_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10afDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10afDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10afDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10afDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AF coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10afContractPath = Join-Path $PSScriptRoot 'development/r10af_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10afContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10af_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AF_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10afStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10afStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10aeSelected) {
        if (-not $singleKickRequested) { throw 'R10AE_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10ae_host_runtime.ps1')
        $Godot = (Get-R10aeExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ae_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AE_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10aeDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10aeDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10aeDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10aeDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AE coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10aeContractPath = Join-Path $PSScriptRoot 'development/r10ae_safety_stage_contract_v2.json'
        if (Test-Path -LiteralPath $r10aeContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ae_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AE_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10aeStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10aeStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    }
    elseif ($r10adSelected) {
        if (-not $singleKickRequested) { throw 'R10AD_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10ad_host_runtime.ps1')
        $Godot = (Get-R10adExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ad_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AD_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10adDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10adDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10adDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10adDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AD coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10adContractPath = Join-Path $PSScriptRoot 'development/r10ad_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10adContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ad_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AD_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10adStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10adStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10acSelected) {
        if (-not $singleKickRequested) { throw 'R10AC_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        . (Join-Path $PSScriptRoot 'r10ac_host_runtime.ps1')
        $Godot = (Get-R10acExpectedRuntimeBinding).images.godot_console.path
        $TimeoutSeconds = 2400
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ac_development_v2.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AC_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10acDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10acDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10acDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10acDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # No fallback to a consumed predecessor's graph. Missing or incomplete
        # R10AC coverage refuses before declaration, reservation or a child.
        $stages = @()
        $r10acContractPath = Join-Path $PSScriptRoot 'development/r10ac_safety_stage_contract_v3.json'
        if (Test-Path -LiteralPath $r10acContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ac_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AC_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10acStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10acStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10abSelected) {
        if (-not $singleKickRequested) { throw 'R10AB_FIRST_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        $TimeoutSeconds = 1740
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ab_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AB_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10abDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10abDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10abDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10abDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # Library mode exposes declaration interfaces before the complete graph
        # is declared. Execution never falls back to an older candidate's gate.
        $stages = @()
        $r10abContractPath = Join-Path $PSScriptRoot 'development/r10ab_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10abContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ab_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AB_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10abStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10abStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10aaSelected) {
        if (-not $singleKickRequested) { throw 'R10AA_FIRST_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        $TimeoutSeconds = 1740
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aa_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10AA_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10aaDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10aaDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10aaDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10aaDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # Library mode exposes declaration interfaces before the complete graph
        # is declared. Execution never falls back to an older candidate's gate.
        $stages = @()
        $r10aaContractPath = Join-Path $PSScriptRoot 'development/r10aa_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10aaContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aa_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10AA_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10aaStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10aaStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10zSelected) {
        if (-not $singleKickRequested) { throw 'R10Z_FIRST_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        $TimeoutSeconds = 1740
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10z_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10Z_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10zDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10zDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10zDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10zDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # Library mode exposes declaration interfaces before the complete graph
        # is declared. Execution never falls back to an older candidate's gate.
        $stages = @()
        $r10zContractPath = Join-Path $PSScriptRoot 'development/r10z_safety_stage_contract_v1.json'
        if (Test-Path -LiteralPath $r10zContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10z_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10Z_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10zStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10zStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10ySelected) {
        if (-not $singleKickRequested) { throw 'R10Y_FIRST_DIAGNOSTIC_REQUIRES_SINGLE_KICK' }
        $TimeoutSeconds = 1740
        $contextArguments = @('--mode', $candidateSelection.single_mode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10y_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10Y_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10yDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10yDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10yDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10yDevelopmentContext.seed.sha256
        $script:OrderedChildRoles = @($candidateSelection.single_role)
        # Library mode exposes declaration interfaces before the complete graph
        # is declared. Execution never falls back to an older candidate's gate.
        $stages = @()
        $r10yContractPath = Join-Path $PSScriptRoot 'development/r10y_safety_stage_contract_v5.json'
        if (Test-Path -LiteralPath $r10yContractPath -PathType Leaf) {
            $contractOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10y_development_launch.py') --contract)
            if ($LASTEXITCODE -ne 0 -or $contractOutput.Count -ne 1) { throw 'R10Y_SAFETY_STAGE_CONTRACT_INVALID' }
            $r10yStageContract = $contractOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($spec in $r10yStageContract.stages) {
                $stage = @{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests}
                if ($spec.candidate_bound) { $stage.candidate_profile = $candidatePathRequested }
                if ($spec.ContainsKey('timeout_seconds')) { $stage.timeout_seconds = [int]$spec.timeout_seconds }
                $stages += $stage
            }
        }
    } elseif ($r10vSelected) {
        $TimeoutSeconds = 1740
        # R10V owns an explicit production safety population. Common stages keep
        # their original runtime selection; affected stages receive this candidate.
        $r10vStageContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10v_safety_stage_contract_v3.json') -Raw | ConvertFrom-Json -AsHashtable
        if ($r10vStageContract.schema_version -cne 'sporespore_r10v_safety_stage_contract_v3' -or
            $r10vStageContract.unbound_common_stage_count -ne 20 -or
            ($r10vStageContract.stages.tests | Measure-Object -Sum).Sum -ne $r10vStageContract.total_tests) {
            throw 'R10V_SAFETY_STAGE_CONTRACT_INVALID'
        }
        $stages = @()
        for ($index = 0; $index -lt $r10vStageContract.stages.Count; $index++) {
            $declared = $r10vStageContract.stages[$index]
            $selected = @{id=$declared.id;pattern=$declared.pattern;tests=[int]$declared.tests}
            if ($index -ge $r10vStageContract.unbound_common_stage_count) { $selected.candidate_profile = $candidatePathRequested }
            if ($r10vStageContract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) {
                $selected.timeout_seconds = [int]$r10vStageContract.stage_timeout_overrides_seconds[$selected.id]
            }
            $stages += $selected
        }
        $r10vDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10vDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10vPrerequisiteRequested) { $contextArguments += @('--prerequisite-root', $r10vPrerequisiteRequested) }
        if ($null -ne $r10vDiagnosticSeedRequested) { $contextArguments += @('--diagnostic-seed', [string]$r10vDiagnosticSeedRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10v_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10V_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10vDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10vDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10vDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10vDevelopmentContext.seed.sha256
        if ($singleKickRequested) { $script:OrderedChildRoles = @($candidateSelection.single_role) }
    } elseif ($r10uSelected) {
        $TimeoutSeconds = 1740
        # R10U owns an explicit production safety population. Common stages keep
        # their original runtime selection; affected stages receive this candidate.
        $r10uStageContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10u_safety_stage_contract_v4.json') -Raw | ConvertFrom-Json -AsHashtable
        if ($r10uStageContract.schema_version -cne 'sporespore_r10u_safety_stage_contract_v4' -or
            $r10uStageContract.unbound_common_stage_count -ne 20 -or
            ($r10uStageContract.stages.tests | Measure-Object -Sum).Sum -ne $r10uStageContract.total_tests) {
            throw 'R10U_SAFETY_STAGE_CONTRACT_INVALID'
        }
        $stages = @()
        for ($index = 0; $index -lt $r10uStageContract.stages.Count; $index++) {
            $declared = $r10uStageContract.stages[$index]
            $selected = @{id=$declared.id;pattern=$declared.pattern;tests=[int]$declared.tests}
            if ($index -ge $r10uStageContract.unbound_common_stage_count) { $selected.candidate_profile = $candidatePathRequested }
            if ($r10uStageContract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) {
                $selected.timeout_seconds = [int]$r10uStageContract.stage_timeout_overrides_seconds[$selected.id]
            }
            $stages += $selected
        }
        $r10uDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10uDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10uPrerequisiteRequested) { $contextArguments += @('--prerequisite-root', $r10uPrerequisiteRequested) }
        if ($null -ne $r10uDiagnosticSeedRequested) { $contextArguments += @('--diagnostic-seed', [string]$r10uDiagnosticSeedRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10u_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10U_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10uDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10uDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10uDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10uDevelopmentContext.seed.sha256
        if ($singleKickRequested) { $script:OrderedChildRoles = @($candidateSelection.single_role) }
    } elseif ($r10tSelected) {
        $TimeoutSeconds = 1740
        # R10T owns an explicit production safety population. Common stages keep
        # their original runtime selection; affected stages receive this candidate.
        $r10tStageContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10t_safety_stage_contract_v5.json') -Raw | ConvertFrom-Json -AsHashtable
        if ($r10tStageContract.schema_version -cne 'sporespore_r10t_safety_stage_contract_v5' -or
            $r10tStageContract.unbound_common_stage_count -ne 20 -or
            ($r10tStageContract.stages.tests | Measure-Object -Sum).Sum -ne $r10tStageContract.total_tests) {
            throw 'R10T_SAFETY_STAGE_CONTRACT_INVALID'
        }
        $stages = @()
        for ($index = 0; $index -lt $r10tStageContract.stages.Count; $index++) {
            $declared = $r10tStageContract.stages[$index]
            $selected = @{id=$declared.id;pattern=$declared.pattern;tests=[int]$declared.tests}
            if ($index -ge $r10tStageContract.unbound_common_stage_count) { $selected.candidate_profile = $candidatePathRequested }
            if ($r10tStageContract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) {
                $selected.timeout_seconds = [int]$r10tStageContract.stage_timeout_overrides_seconds[$selected.id]
            }
            $stages += $selected
        }
        $r10tDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10tDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10tPrerequisiteRequested) { $contextArguments += @('--prerequisite-root', $r10tPrerequisiteRequested) }
        if ($null -ne $r10tDiagnosticSeedRequested) { $contextArguments += @('--diagnostic-seed', [string]$r10tDiagnosticSeedRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10t_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10T_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10tDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10tDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10tDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10tDevelopmentContext.seed.sha256
        if ($singleKickRequested) { $script:OrderedChildRoles = @($candidateSelection.single_role) }
    } elseif ($r10sSelected) {
        # R10S owns an explicit production safety population. Common stages keep
        # their original runtime selection; affected stages receive this candidate.
        $r10sStageContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10s_safety_stage_contract_v2.json') -Raw | ConvertFrom-Json -AsHashtable
        if ($r10sStageContract.schema_version -cne 'sporespore_r10s_safety_stage_contract_v2' -or
            $r10sStageContract.unbound_common_stage_count -ne 13 -or
            ($r10sStageContract.stages.tests | Measure-Object -Sum).Sum -ne $r10sStageContract.total_tests) {
            throw 'R10S_SAFETY_STAGE_CONTRACT_INVALID'
        }
        $stages = @()
        for ($index = 0; $index -lt $r10sStageContract.stages.Count; $index++) {
            $declared = $r10sStageContract.stages[$index]
            $selected = @{id=$declared.id;pattern=$declared.pattern;tests=[int]$declared.tests}
            if ($index -ge $r10sStageContract.unbound_common_stage_count) { $selected.candidate_profile = $candidatePathRequested }
            if ($r10sStageContract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) {
                $selected.timeout_seconds = [int]$r10sStageContract.stage_timeout_overrides_seconds[$selected.id]
            }
            $stages += $selected
        }
        $r10sDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10sDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10sPrerequisiteRequested) { $contextArguments += @('--prerequisite-root', $r10sPrerequisiteRequested) }
        if ($null -ne $r10sDiagnosticSeedRequested) { $contextArguments += @('--diagnostic-seed', [string]$r10sDiagnosticSeedRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10s_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10S_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10sDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10sDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10sDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10sDevelopmentContext.seed.sha256
        if ($singleKickRequested) { $script:OrderedChildRoles = @($candidateSelection.single_role) }
    } elseif ($r10rSelected) {
        # R10R owns an explicit production safety population. Common stages keep
        # their original runtime selection; affected stages receive this candidate.
        $r10rStageContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10r_safety_stage_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable
        if ($r10rStageContract.schema_version -cne 'sporespore_r10r_safety_stage_contract_v1' -or
            $r10rStageContract.unbound_common_stage_count -ne 13 -or
            ($r10rStageContract.stages.tests | Measure-Object -Sum).Sum -ne $r10rStageContract.total_tests) {
            throw 'R10R_SAFETY_STAGE_CONTRACT_INVALID'
        }
        $stages = @()
        for ($index = 0; $index -lt $r10rStageContract.stages.Count; $index++) {
            $declared = $r10rStageContract.stages[$index]
            $selected = @{id=$declared.id;pattern=$declared.pattern;tests=[int]$declared.tests}
            if ($index -ge $r10rStageContract.unbound_common_stage_count) { $selected.candidate_profile = $candidatePathRequested }
            if ($r10rStageContract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) {
                $selected.timeout_seconds = [int]$r10rStageContract.stage_timeout_overrides_seconds[$selected.id]
            }
            $stages += $selected
        }
        $r10rDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10rDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10rPrerequisiteRequested) { $contextArguments += @('--prerequisite-root', $r10rPrerequisiteRequested) }
        if ($null -ne $r10rDiagnosticSeedRequested) { $contextArguments += @('--diagnostic-seed', [string]$r10rDiagnosticSeedRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10r_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10R_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10rDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10rDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10rDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10rDevelopmentContext.seed.sha256
        if ($singleKickRequested) { $script:OrderedChildRoles = @($candidateSelection.single_role) }
    } elseif ($r10qSelected) {
        # R10Q owns an explicit production safety population. Common stages keep
        # their original runtime selection; affected stages receive this candidate.
        $r10qStageContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10q_safety_stage_contract_v3.json') -Raw | ConvertFrom-Json -AsHashtable
        if ($r10qStageContract.schema_version -cne 'sporespore_r10q_safety_stage_contract_v3' -or
            $r10qStageContract.unbound_common_stage_count -ne 13 -or
            ($r10qStageContract.stages.tests | Measure-Object -Sum).Sum -ne $r10qStageContract.total_tests) {
            throw 'R10Q_SAFETY_STAGE_CONTRACT_INVALID'
        }
        $stages = @()
        for ($index = 0; $index -lt $r10qStageContract.stages.Count; $index++) {
            $declared = $r10qStageContract.stages[$index]
            $selected = @{id=$declared.id;pattern=$declared.pattern;tests=[int]$declared.tests}
            if ($index -ge $r10qStageContract.unbound_common_stage_count) { $selected.candidate_profile = $candidatePathRequested }
            if ($r10qStageContract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) {
                $selected.timeout_seconds = [int]$r10qStageContract.stage_timeout_overrides_seconds[$selected.id]
            }
            $stages += $selected
        }
        $r10qDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10qDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10qPositivePairRequested) { $contextArguments += @('--prerequisite-root', $r10qPositivePairRequested) }
        if ($null -ne $r10qDiagnosticSeedRequested) { $contextArguments += @('--diagnostic-seed', [string]$r10qDiagnosticSeedRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10q_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10Q_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10qDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10qDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10qDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10qDevelopmentContext.seed.sha256
        if ($singleKickRequested) { $script:OrderedChildRoles = @($candidateSelection.single_role) }
    } else {
    $stages += @(
        @{id='candidate_profile';pattern=$(if ($r10oSelected) {'test_development_r10o_launcher.py'} elseif ($r10nSelected) {'test_development_r10n_launcher.py'} elseif ($r10mSelected) {'test_development_r10m_launcher.py'} elseif ($r10lSelected) {'test_development_r10l_launcher.py'} elseif ($r10kSelected) {'test_development_r10k_launcher.py'} else {'test_development_recovery_candidate_profile.py'});tests=5;candidate_profile=$candidatePathRequested},
        @{id='candidate_runtime';pattern='test_development_recovery_candidate_runtime.py';tests=4;candidate_profile=$candidatePathRequested},
        @{id='candidate_transport';pattern='test_development_recovery_candidate_transport.py';tests=7;candidate_profile=$candidatePathRequested},
        @{id='candidate_reader';pattern=$(if ($r10oSelected) {'test_development_r10o_complete_report.py'} elseif ($r10nSelected) {'test_development_r10n_complete_report.py'} elseif ($r10mSelected) {'test_development_r10m_complete_report.py'} elseif ($r10lSelected) {'test_development_r10l_complete_report.py'} elseif ($r10kSelected) {'test_development_r10k_complete_report.py'} else {'test_development_recovery_candidate_replay.py'});tests=$(if ($r10oSelected -or $r10nSelected -or $r10mSelected -or $r10lSelected -or $r10kSelected) {2} else {8});candidate_profile=$candidatePathRequested}
    )
    if ($r10kSelected) {
        $stages += @(
            @{id='r10k_native_control';pattern='test_development_r10k_control_component.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10k_source_bridges';pattern='test_development_r10k_source_bridges.py';tests=2;candidate_profile=$candidatePathRequested},
            @{id='r10k_worker';pattern='test_development_r10k_worker_component.py';tests=4;candidate_profile=$candidatePathRequested},
            @{id='r10k_recovery_reader';pattern='test_development_r10k_recovery_replay.py';tests=3;candidate_profile=$candidatePathRequested},
            @{id='r10k_declaration';pattern='test_development_r10k_declaration.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10k_finite_task';pattern='test_r10k_finite_task_audit.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10k_preparation_report';pattern='test_development_r10k_preparation_report.py';tests=2;candidate_profile=$candidatePathRequested}
        )
        foreach ($r10kLongStage in @($stages | Where-Object { $_.id -in @('candidate_reader','r10k_worker','r10k_recovery_reader','r10k_preparation_report') })) {
            $r10kLongStage.timeout_seconds = 600
        }
    }
    if ($r10oSelected) {
        $stages += @(
            @{id='r10o_extended_transfer';pattern='test_development_r10o_extended_transfer.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10o_zero_brake';pattern='test_development_r10o_zero_brake.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10o_native_adapter';pattern='test_development_v55_walking_adapter.py';tests=1;candidate_profile=$candidatePathRequested},
            @{id='r10o_native_control';pattern='test_development_r10o_control_component.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10o_source_bridges';pattern='test_development_r10o_source_bridges.py';tests=2;candidate_profile=$candidatePathRequested},
            @{id='r10o_worker';pattern='test_development_r10o_worker_component.py';tests=4;candidate_profile=$candidatePathRequested},
            @{id='r10o_recovery_reader';pattern='test_development_r10o_recovery_replay.py';tests=3;candidate_profile=$candidatePathRequested},
            @{id='r10o_declaration';pattern='test_development_r10o_declaration.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10o_finite_task';pattern='test_r10o_finite_task_audit.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10o_preparation_report';pattern='test_development_r10o_preparation_report.py';tests=2;candidate_profile=$candidatePathRequested}
        )
        foreach ($r10oLongStage in @($stages | Where-Object { $_.id -in @('candidate_reader','r10o_worker','r10o_recovery_reader','r10o_preparation_report') })) {
            $r10oLongStage.timeout_seconds = if ($r10oLongStage.id -ceq 'r10o_preparation_report') { 900 } else { 600 }
        }
    }
    if ($r10nSelected) {
        $stages += @(
            @{id='r10n_extended_transfer';pattern='test_development_r10n_extended_transfer.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10n_zero_brake';pattern='test_development_r10n_zero_brake.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10n_native_adapter';pattern='test_development_v54_walking_adapter.py';tests=1;candidate_profile=$candidatePathRequested},
            @{id='r10n_native_control';pattern='test_development_r10n_control_component.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10n_source_bridges';pattern='test_development_r10n_source_bridges.py';tests=2;candidate_profile=$candidatePathRequested},
            @{id='r10n_worker';pattern='test_development_r10n_worker_component.py';tests=4;candidate_profile=$candidatePathRequested},
            @{id='r10n_recovery_reader';pattern='test_development_r10n_recovery_replay.py';tests=3;candidate_profile=$candidatePathRequested},
            @{id='r10n_declaration';pattern='test_development_r10n_declaration.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10n_finite_task';pattern='test_r10n_finite_task_audit.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10n_preparation_report';pattern='test_development_r10n_preparation_report.py';tests=2;candidate_profile=$candidatePathRequested}
        )
        foreach ($r10nLongStage in @($stages | Where-Object { $_.id -in @('candidate_reader','r10n_worker','r10n_recovery_reader','r10n_preparation_report') })) {
            $r10nLongStage.timeout_seconds = if ($r10nLongStage.id -ceq 'r10n_preparation_report') { 900 } else { 600 }
        }
    }
    if ($r10mSelected) {
        $stages += @(
            @{id='r10m_extended_transfer';pattern='test_development_r10m_extended_transfer.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10m_bounded_stop';pattern='test_development_r10m_bounded_stop.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10m_native_adapter';pattern='test_development_v53_walking_adapter.py';tests=1;candidate_profile=$candidatePathRequested},
            @{id='r10m_native_control';pattern='test_development_r10m_control_component.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10m_source_bridges';pattern='test_development_r10m_source_bridges.py';tests=2;candidate_profile=$candidatePathRequested},
            @{id='r10m_worker';pattern='test_development_r10m_worker_component.py';tests=4;candidate_profile=$candidatePathRequested},
            @{id='r10m_recovery_reader';pattern='test_development_r10m_recovery_replay.py';tests=3;candidate_profile=$candidatePathRequested},
            @{id='r10m_declaration';pattern='test_development_r10m_declaration.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10m_finite_task';pattern='test_r10m_finite_task_audit.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10m_preparation_report';pattern='test_development_r10m_preparation_report.py';tests=2;candidate_profile=$candidatePathRequested}
        )
        foreach ($r10mLongStage in @($stages | Where-Object { $_.id -in @('candidate_reader','r10m_worker','r10m_recovery_reader','r10m_preparation_report') })) {
            $r10mLongStage.timeout_seconds = if ($r10mLongStage.id -ceq 'r10m_preparation_report') { 900 } else { 600 }
        }
    }
    if ($r10lSelected) {
        $stages += @(
            @{id='r10l_extended_transfer';pattern='test_development_r10l_extended_transfer.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10l_native_adapter';pattern='test_development_v52_walking_adapter.py';tests=1;candidate_profile=$candidatePathRequested},
            @{id='r10l_native_control';pattern='test_development_r10l_control_component.py';tests=6;candidate_profile=$candidatePathRequested},
            @{id='r10l_source_bridges';pattern='test_development_r10l_source_bridges.py';tests=2;candidate_profile=$candidatePathRequested},
            @{id='r10l_worker';pattern='test_development_r10l_worker_component.py';tests=4;candidate_profile=$candidatePathRequested},
            @{id='r10l_recovery_reader';pattern='test_development_r10l_recovery_replay.py';tests=3;candidate_profile=$candidatePathRequested},
            @{id='r10l_declaration';pattern='test_development_r10l_declaration.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10l_finite_task';pattern='test_r10l_finite_task_audit.py';tests=5;candidate_profile=$candidatePathRequested},
            @{id='r10l_preparation_report';pattern='test_development_r10l_preparation_report.py';tests=2;candidate_profile=$candidatePathRequested}
        )
        foreach ($r10lLongStage in @($stages | Where-Object { $_.id -in @('candidate_reader','r10l_worker','r10l_recovery_reader','r10l_preparation_report') })) {
            $r10lLongStage.timeout_seconds = 600
        }
    }
    if ($candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10k_v51_partial_fall_recovery_route_v1') {
        $r10kDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10kDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10kPositivePairRequested) { $contextArguments += @('--prerequisite-root', $r10kPositivePairRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10k_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10K_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10kDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10kDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10kDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10kDevelopmentContext.seed.sha256
    } elseif ($r10kPositivePairRequested) { throw 'R10K_PREREQUISITE_REQUIRES_R10K_ROUTE' }
    if ($candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10o_v55_partial_fall_recovery_route_v1') {
        $r10oDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10oDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10oPositivePairRequested) { $contextArguments += @('--prerequisite-root', $r10oPositivePairRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10o_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10O_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10oDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10oDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10oDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10oDevelopmentContext.seed.sha256
    } elseif ($r10oPositivePairRequested) { throw 'R10O_PREREQUISITE_REQUIRES_R10O_ROUTE' }
    if ($candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10n_v54_partial_fall_recovery_route_v1') {
        $r10nDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10nDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10nPositivePairRequested) { $contextArguments += @('--prerequisite-root', $r10nPositivePairRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10n_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10N_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10nDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10nDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10nDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10nDevelopmentContext.seed.sha256
    } elseif ($r10nPositivePairRequested) { throw 'R10N_PREREQUISITE_REQUIRES_R10N_ROUTE' }
    if ($candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10m_v53_partial_fall_recovery_route_v1') {
        $r10mDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10mDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10mPositivePairRequested) { $contextArguments += @('--prerequisite-root', $r10mPositivePairRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10m_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10M_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10mDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10mDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10mDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10mDevelopmentContext.seed.sha256
    } elseif ($r10mPositivePairRequested) { throw 'R10M_PREREQUISITE_REQUIRES_R10M_ROUTE' }
    if ($candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10l_v52_partial_fall_recovery_route_v1') {
        $r10lDevelopmentMode = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
        $contextArguments = @('--mode', $r10lDevelopmentMode, '--source-commit', (& git -C $repoRoot rev-parse HEAD),
            '--candidate-resource', $candidateSelection.candidate_profile.resource,
            '--candidate-sha256', $candidateSelection.candidate_profile.raw_sha256)
        if ($r10lPositivePairRequested) { $contextArguments += @('--prerequisite-root', $r10lPositivePairRequested) }
        $contextOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10l_development.py') @contextArguments)
        if ($LASTEXITCODE -ne 0 -or $contextOutput.Count -ne 1) { throw 'R10L_DEVELOPMENT_CONTEXT_REFUSED' }
        $r10lDevelopmentContext = $contextOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
        $script:DevelopmentSeed = $r10lDevelopmentContext.seed.seed
        $script:DevelopmentSeedLabel = $r10lDevelopmentContext.seed.label
        $script:DevelopmentSeedSha256 = $r10lDevelopmentContext.seed.sha256
    } elseif ($r10lPositivePairRequested) { throw 'R10L_PREREQUISITE_REQUIRES_R10L_ROUTE' }
    if ($executeSmoke -and $singleKickRequested -and $candidateSelection.Contains('diagnostic_schedule') -and $candidateSelection.diagnostic_schedule.walking_policy_id -in @('r10g_v50_finite_cycle_walking_route_v1','r10h_v50_stance_entry_route_v1','r10i_v50_flexed_entry_route_v1','r10j_v50_settled_hold_route_v1')) { throw 'FINITE_RECOVERY_REQUIRES_BOTH_FRESH_ROLES' }
    if ($singleKickRequested) { $script:OrderedChildRoles = @($candidateSelection.single_role) }
    if ($candidateSelection.Contains('diagnostic_schedule')) {
        $remainingSupportSelected = $r10oSelected -or $r10nSelected -or $r10mSelected -or $r10lSelected -or $r10kSelected -or ($candidateSelection.diagnostic_schedule.Contains('walking_policy_id') -and $candidateSelection.diagnostic_schedule.walking_policy_id -in @('sporespore_balanced_wave_recovery_remaining_support_release_v1','sporespore_balanced_wave_recovery_startup_reference_velocity_v1','r10g_v50_finite_cycle_walking_route_v1','r10h_v50_stance_entry_route_v1','r10i_v50_flexed_entry_route_v1','r10j_v50_settled_hold_route_v1'))
        if ($candidateSelection.diagnostic_schedule.Contains('walking_start_profile_id') -and $candidateSelection.diagnostic_schedule.walking_start_profile_id -and -not $remainingSupportSelected) {
            $stages += @{id='candidate_walking_start';pattern='test_development_recovery_walking_start.py';tests=4;candidate_profile=$candidatePathRequested}
        }
        $schedulePattern = if ($r10oSelected) { 'test_development_r10o_candidate_schedule.py' } elseif ($r10nSelected) { 'test_development_r10n_candidate_schedule.py' } elseif ($r10mSelected) { 'test_development_r10m_candidate_schedule.py' } elseif ($r10lSelected) { 'test_development_r10l_candidate_schedule.py' } elseif ($r10kSelected) { 'test_development_r10k_candidate_schedule.py' } elseif ($candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10j_v50_settled_hold_route_v1') { 'test_development_r10j_candidate_schedule.py' } elseif ($candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10i_v50_flexed_entry_route_v1') { 'test_development_r10i_candidate_schedule.py' } elseif ($candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10h_v50_stance_entry_route_v1') { 'test_development_r10h_candidate_schedule.py' } elseif ($candidateSelection.diagnostic_schedule.walking_policy_id -eq 'r10g_v50_finite_cycle_walking_route_v1') { 'test_development_r10g_candidate_schedule.py' } elseif ($remainingSupportSelected -and $candidateSelection.diagnostic_schedule.walking_policy_id -eq 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1') { 'test_development_v50_candidate_schedule.py' } elseif ($remainingSupportSelected) { 'test_development_v49_candidate_schedule.py' } else { 'test_development_recovery_candidate_schedule.py' }
        $stages += @{id='candidate_schedule';pattern=$schedulePattern;tests=4;candidate_profile=$candidatePathRequested}
        if ($candidateSelection.diagnostic_schedule.Contains('walking_policy_id') -and $candidateSelection.diagnostic_schedule.walking_policy_id) {
            $stages += @{id='candidate_native_step_failure';pattern='test_development_native_step_failure.py';tests=3;candidate_profile=$candidatePathRequested}
            $walkingTestVariant = switch ($candidateSelection.diagnostic_schedule.walking_policy_id) {
                'sporespore_balanced_wave_recovery_absent_contact_reference_v1' { 'v40' }
                'sporespore_balanced_wave_recovery_upright_stance_v1' { 'v41' }
                'sporespore_balanced_wave_recovery_stance_latched_upright_v1' { 'v42' }
                'sporespore_balanced_wave_recovery_support_progression_v1' { 'v43' }
                'r10g_v50_finite_cycle_walking_route_v1' { 'r10g' }
                'r10h_v50_stance_entry_route_v1' { 'r10h' }
                'r10i_v50_flexed_entry_route_v1' { 'r10i' }
                'r10j_v50_settled_hold_route_v1' { 'r10j' }
                'r10k_v51_partial_fall_recovery_route_v1' { 'r10k' }
                'r10o_v55_partial_fall_recovery_route_v1' { 'r10o' }
                'r10n_v54_partial_fall_recovery_route_v1' { 'r10n' }
                'r10m_v53_partial_fall_recovery_route_v1' { 'r10m' }
                'r10l_v52_partial_fall_recovery_route_v1' { 'r10l' }
                'sporespore_balanced_wave_recovery_startup_reference_velocity_v1' { 'v50' }
                'sporespore_balanced_wave_recovery_remaining_support_release_v1' { 'v49' }
                'sporespore_balanced_wave_recovery_support_hold_posture_v1' { 'v44' }
                'sporespore_balanced_wave_recovery_airborne_reference_v1' { 'v39' }
                'sporespore_balanced_wave_recovery_wave_velocity_v1' { 'v38' }
                'sporespore_balanced_wave_recovery_reference_velocity_v1' { 'v37' }
                'sporespore_balanced_wave_recovery_smooth_swing_v1' { 'v36' }
                'sporespore_balanced_wave_recovery_feasible_support_v1' { 'v35' }
                'sporespore_balanced_wave_recovery_floor_support_v1' { 'v34' }
                'sporespore_balanced_wave_recovery_bounded_support_v1' { 'v33' }
                default { 'v32' }
            }
            if ($walkingTestVariant -in @('r10i','r10j','r10k','r10l','r10m','r10n','r10o')) {
                $stages += @{id='walking_entry_readiness';pattern='test_recovery_walking_readiness.py';tests=7;candidate_profile=$candidatePathRequested}
                $stages += @{id='walking_joint_entry_interfaces';pattern='test_recovery_joint_pose_entry_interfaces.py';tests=5;candidate_profile=$candidatePathRequested}
                $stages += @{id='walking_joint_entry_boundaries';pattern='test_recovery_joint_pose_entry_boundaries.py';tests=3;candidate_profile=$candidatePathRequested}
            }
            if ($walkingTestVariant -in @('r10j','r10k','r10l','r10m','r10n','r10o')) {
                $stages += @{id='walking_hold_entry_boundaries';pattern='test_recovery_v50_hold_entry_boundaries.py';tests=3;candidate_profile=$candidatePathRequested}
            }
            if ($walkingTestVariant -eq 'r10h') {
                $stages += @{id='walking_entry_readiness';pattern='test_recovery_walking_readiness.py';tests=7;candidate_profile=$candidatePathRequested}
                $stages += @{id='walking_entry_interfaces';pattern='test_recovery_stance_entry.py';tests=5;candidate_profile=$candidatePathRequested}
            }
            if ($walkingTestVariant -in @('r10g','r10h','r10i','r10j','r10k','r10l','r10m','r10n','r10o')) { $stages += @{id='finite_recovery_measurements';pattern='test_finite_recovery_walking.py';tests=7;candidate_profile=$candidatePathRequested} }
            if ($walkingTestVariant -in @('v49','v50','r10g','r10h','r10i','r10j','r10k','r10l','r10m','r10n','r10o')) {
                $stages += @{id='candidate_measured_body_adapter';pattern=('test_development_{0}_measured_body_adapter.py' -f $walkingTestVariant);tests=$(if ($walkingTestVariant -in @('r10g','r10h','r10i','r10j','r10k','r10l','r10m','r10n','r10o')) {28} else {14});candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_cycle_stop';pattern=('test_development_{0}_cycle_stop.py' -f $walkingTestVariant);tests=3;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_legacy_source';pattern='test_development_v42_legacy_source.py';tests=1;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v44') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v44_floor_adapter.py';tests=5;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_legacy_source';pattern='test_development_v42_legacy_source.py';tests=1;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_support_hold_posture_native';pattern='test_development_support_hold_posture_component.py';tests=5;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_support_hold_posture_reader';pattern='test_development_v44_posture_reader.py';tests=1;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v43') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v43_floor_adapter.py';tests=5;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_legacy_source';pattern='test_development_v42_legacy_source.py';tests=1;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_support_progression_native';pattern='test_development_v43_support_progression_component.py';tests=4;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_support_progression_reader';pattern='test_development_v43_progression_reader.py';tests=1;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v42') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v42_floor_adapter.py';tests=5;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_legacy_source';pattern='test_development_v42_legacy_source.py';tests=1;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_stance_latch_native';pattern='test_development_v42_stance_latch_component.py';tests=4;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v41') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v41_floor_adapter.py';tests=6;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_upright_stance_native';pattern='test_development_v41_upright_stance_component.py';tests=4;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v40') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v40_floor_adapter.py';tests=6;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_absent_contact_reference_native';pattern='test_development_v40_absent_contact_reference_component.py';tests=4;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v39') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v39_floor_adapter.py';tests=6;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_airborne_reference_native';pattern='test_development_v39_airborne_reference_component.py';tests=4;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v38') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v38_floor_adapter.py';tests=6;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_wave_velocity_native';pattern='test_development_v38_wave_velocity_component.py';tests=4;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v37') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v37_floor_adapter.py';tests=6;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_reference_velocity_native';pattern='test_development_v37_reference_velocity_component.py';tests=4;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v36') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v36_floor_adapter.py';tests=6;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_smooth_swing_native';pattern='test_development_v36_smooth_swing_component.py';tests=5;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v35') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v35_floor_adapter.py';tests=6;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_feasible_support_native';pattern='test_development_v35_feasible_support_component.py';tests=4;candidate_profile=$candidatePathRequested}
            } elseif ($walkingTestVariant -eq 'v34') {
                $stages += @{id='candidate_walking_policy';pattern='test_development_v34_floor_adapter.py';tests=6;candidate_profile=$candidatePathRequested}
                $stages += @{id='candidate_floor_support_native';pattern='test_development_v34_floor_support_component.py';tests=4;candidate_profile=$candidatePathRequested}
            } else {
                $stages += @{id='candidate_walking_policy';pattern="test_development_${walkingTestVariant}_walking_policy.py";tests=5;candidate_profile=$candidatePathRequested}
            }
            $stages += @{id='candidate_recovery_route';pattern=$(if ($r10oSelected) {'test_development_r10o_route_selection.py'} elseif ($r10nSelected) {'test_development_r10n_route_selection.py'} elseif ($r10mSelected) {'test_development_r10m_route_selection.py'} elseif ($r10lSelected) {'test_development_r10l_route_selection.py'} elseif ($r10kSelected) {'test_development_r10k_route_selection.py'} else {"test_development_${walkingTestVariant}_recovery_route.py"});tests=$(if ($r10kSelected) {2} else {4});candidate_profile=$candidatePathRequested}
            if ($walkingTestVariant -eq 'v33') {
                $stages += @{id='candidate_bounded_support_native';pattern='test_development_v33_bounded_support_component.py';tests=4;candidate_profile=$candidatePathRequested}
            }
        }
        if ($candidateSelection.diagnostic_schedule.Contains('walking_resume_frame_id') -and $candidateSelection.diagnostic_schedule.walking_resume_frame_id) {
            $stages += @{id='candidate_walking_frame';pattern='test_development_recovery_walking_frame.py';tests=4;candidate_profile=$candidatePathRequested}
        }
        if ($candidateSelection.diagnostic_schedule.Contains('walking_entry_profile_id') -and $candidateSelection.diagnostic_schedule.walking_entry_profile_id -and -not $remainingSupportSelected) {
            $stages += @{id='candidate_walking_entry';pattern='test_development_recovery_walking_entry.py';tests=6;candidate_profile=$candidatePathRequested}
        }
        if ($candidateSelection.diagnostic_schedule.Contains('walking_replay_profile_id') -and $candidateSelection.diagnostic_schedule.walking_replay_profile_id) {
            $stages += @{id='candidate_walking_transition';pattern='test_development_walking_memory_transition.py';tests=4;candidate_profile=$candidatePathRequested}
            $stages += @{id='candidate_prospective_replay';pattern='test_development_prospective_walking_replay.py';tests=4;candidate_profile=$candidatePathRequested}
        }
        if ($candidateSelection.diagnostic_schedule.Contains('walking_contact_profile_id') -and $candidateSelection.diagnostic_schedule.walking_contact_profile_id) {
            $nativeContactContract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/recovery_native_walking_contact_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable
            $nativeContactSelected = $candidateSelection.diagnostic_schedule.walking_contact_profile_id -eq $nativeContactContract.profile_id
            # The legacy shape-contact branch is a synthetic interface fixture.
            # Use the selected, source-bound runtime; an old candidate's source
            # key is invalid after a new core build and must never be waived.
            $stages += @{id='candidate_walking_contacts';pattern='test_development_recovery_walking_contacts.py';tests=4;candidate_profile=$candidatePathRequested}
            if ($nativeContactSelected) {
                $stages += @{id='candidate_native_walking_contacts';pattern='test_development_recovery_native_walking_contacts.py';tests=4;candidate_profile=$candidatePathRequested}
            }
        }
    }
    }
}

function Get-DevelopmentCandidateFields {
    $fields = Get-DevelopmentMeasuredEntryFields
    $fields.schema_version = $candidateSelection.worker_selection.declaration_schema
    $fields.diagnostic_schedule_id = $candidateSelection.worker_selection.schedule
    $entryBinding = Get-Content -LiteralPath (Join-Path $repoRoot $candidateSelection.candidate.runtime_binding.Replace('res://', '')) -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $fields.passive_entry_runtime = $entryBinding.runtime
    $fields.coverage_question = $candidateSelection.candidate.coverage_question
    $fields.coverage_adequacy = 'One development seed, fresh V6 setup and full bounded post-kick tail. Single-kick mode diagnoses this controller only: no matched comparison, no cached baseline, no full paired commissioning. Default paired mode creates both roles fresh. Acceptance and held-out gates are unchanged.'
    $fields['candidate_profile'] = $candidateSelection.candidate_profile
    $fields['development_execution_mode'] = if ($singleKickRequested) { $candidateSelection.single_mode } else { $candidateSelection.paired_mode }
    $fields['comparative_authority'] = $false
    $fields['baseline_reused'] = $false
    if ($candidateSelection.Contains('diagnostic_schedule')) {
        $remainingSupportSelected = $r10oSelected -or $r10nSelected -or $r10mSelected -or $r10lSelected -or $r10kSelected -or ($candidateSelection.diagnostic_schedule.Contains('walking_policy_id') -and $candidateSelection.diagnostic_schedule.walking_policy_id -in @('sporespore_balanced_wave_recovery_remaining_support_release_v1','sporespore_balanced_wave_recovery_startup_reference_velocity_v1','r10g_v50_finite_cycle_walking_route_v1','r10h_v50_stance_entry_route_v1','r10i_v50_flexed_entry_route_v1','r10j_v50_settled_hold_route_v1'))
        foreach ($key in $candidateSelection.diagnostic_schedule.limits.Keys) {
            $fields[$key] = $candidateSelection.diagnostic_schedule.limits[$key]
        }
        $fields.coverage_adequacy = $candidateSelection.diagnostic_schedule.coverage_adequacy
        $fields.uncovered_paths = $candidateSelection.diagnostic_schedule.uncovered_paths
    }
    if ($r10apSelected) {
        $r10apDesignPath = Join-Path $PSScriptRoot 'recovery/r10ap_progressive_headroom_development_design_v1.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10apDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10apDevelopmentContext.design_binding.raw_sha256) { throw 'R10AP_HOST_DEADLINE_DESIGN' }
        $r10apDesign = Get-Content -LiteralPath $r10apDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10apDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10apDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10ap_development'] = $r10apDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    }
    elseif ($r10amSelected) {
        $r10amDesignPath = Join-Path $PSScriptRoot 'recovery/r10am_support_anchored_development_design_v1.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10amDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10amDevelopmentContext.design_binding.raw_sha256) { throw 'R10AM_HOST_DEADLINE_DESIGN' }
        $r10amDesign = Get-Content -LiteralPath $r10amDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10amDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10amDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10am_development'] = $r10amDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    }
    elseif ($r10ajSelected) {
        $r10ajDesignPath = Join-Path $PSScriptRoot 'recovery/r10aj_hip_recenter_development_design_v1.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10ajDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10ajDevelopmentContext.design_binding.raw_sha256) { throw 'R10AJ_HOST_DEADLINE_DESIGN' }
        $r10ajDesign = Get-Content -LiteralPath $r10ajDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10ajDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10ajDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10aj_development'] = $r10ajDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    }
    elseif ($r10aiSelected) {
        $r10aiDesignPath = Join-Path $PSScriptRoot 'recovery/r10ai_concurrent_load_rise_development_design_v1.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10aiDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10aiDevelopmentContext.design_binding.raw_sha256) { throw 'R10AI_HOST_DEADLINE_DESIGN' }
        $r10aiDesign = Get-Content -LiteralPath $r10aiDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10aiDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10aiDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10ai_development'] = $r10aiDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    } elseif ($r10agSelected) {
        $r10agDesignPath = Join-Path $PSScriptRoot 'recovery/r10ag_detection_frame_load_seeking_design_v1.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10agDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10agDevelopmentContext.design_binding.raw_sha256) { throw 'R10AG_HOST_DEADLINE_DESIGN' }
        $r10agDesign = Get-Content -LiteralPath $r10agDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10agDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10agDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10ag_development'] = $r10agDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    } elseif ($r10afSelected) {
        $r10afDesignPath = Join-Path $PSScriptRoot 'recovery/r10af_detection_frame_development_design_v1.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10afDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10afDevelopmentContext.design_binding.raw_sha256) { throw 'R10AF_HOST_DEADLINE_DESIGN' }
        $r10afDesign = Get-Content -LiteralPath $r10afDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10afDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10afDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10af_development'] = $r10afDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    } elseif ($r10aeSelected) {
        $r10aeDesignPath = Join-Path $PSScriptRoot 'recovery/r10ae_contact_frame_development_design_v1.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10aeDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10aeDevelopmentContext.design_binding.raw_sha256) { throw 'R10AE_HOST_DEADLINE_DESIGN' }
        $r10aeDesign = Get-Content -LiteralPath $r10aeDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10aeDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10aeDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10ae_development'] = $r10aeDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    }
    if ($r10adSelected) {
        $r10adDesignPath = Join-Path $PSScriptRoot 'recovery/r10ad_contact_frame_development_design_v1.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10adDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10adDevelopmentContext.design_binding.raw_sha256) { throw 'R10AD_HOST_DEADLINE_DESIGN' }
        $r10adDesign = Get-Content -LiteralPath $r10adDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10adDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10adDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10ad_development'] = $r10adDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    }
    if ($r10acSelected) {
        $r10acDesignPath = Join-Path $PSScriptRoot 'recovery/r10ac_contact_frame_development_design_v2.json'
        if ('sha256:' + (Get-FileHash -LiteralPath $r10acDesignPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
            $r10acDevelopmentContext.design_binding.raw_sha256) { throw 'R10AC_HOST_DEADLINE_DESIGN' }
        $r10acDesign = Get-Content -LiteralPath $r10acDesignPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $fields.timeout_seconds_per_child = $r10acDesign.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10acDesign.limits.independent_reader_wall_time_limit_seconds
        $fields['r10ac_development'] = $r10acDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_contact_frame_diagnostic';question_class='development'}
    }
    if ($r10abSelected) {
        $r10abTaskPath = Join-Path $PSScriptRoot 'recovery/r10ab_partial_downward_rise_finite_cycle_contract_v2.json'
        $r10abTaskSha = 'sha256:' + (Get-FileHash -LiteralPath $r10abTaskPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($r10abTaskSha -cne 'sha256:bd8bf8b616a80c7f5c2b5070324350c0d8d66e9543f3598bc9edb067982cb83c') { throw 'R10AB_HOST_DEADLINE_TASK' }
        $r10abTask = Get-Content -LiteralPath $r10abTaskPath -Raw | ConvertFrom-Json -AsHashtable
        $fields.timeout_seconds_per_child = $r10abTask.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10abTask.limits.independent_reader_wall_time_limit_seconds
        $fields['r10ab_development'] = $r10abDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10aaSelected) {
        $r10aaTaskPath = Join-Path $PSScriptRoot 'recovery/r10aa_partial_load_seeking_finite_cycle_contract_v1.json'
        $r10aaTaskSha = 'sha256:' + (Get-FileHash -LiteralPath $r10aaTaskPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($r10aaTaskSha -cne 'sha256:b96cb43aed32be4224bbeb62f050bbabedcde9a2578efc8e262c4a0f823dc76f') { throw 'R10AA_HOST_DEADLINE_TASK' }
        $r10aaTask = Get-Content -LiteralPath $r10aaTaskPath -Raw | ConvertFrom-Json -AsHashtable
        $fields.timeout_seconds_per_child = $r10aaTask.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10aaTask.limits.independent_reader_wall_time_limit_seconds
        $fields['r10aa_development'] = $r10aaDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10zSelected) {
        $r10zTaskPath = Join-Path $PSScriptRoot 'recovery/r10z_partial_pose_geometry_finite_cycle_contract_v1.json'
        $r10zTaskSha = 'sha256:' + (Get-FileHash -LiteralPath $r10zTaskPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($r10zTaskSha -cne 'sha256:1a8aaaff4fbb164bfb03adb9eeb0dc0ca8ea790de82f2c58836ccad4236c472f') { throw 'R10Z_HOST_DEADLINE_TASK' }
        $r10zTask = Get-Content -LiteralPath $r10zTaskPath -Raw | ConvertFrom-Json -AsHashtable
        $fields.timeout_seconds_per_child = $r10zTask.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10zTask.limits.independent_reader_wall_time_limit_seconds
        $fields['r10z_development'] = $r10zDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10ySelected) {
        $r10yTaskPath = Join-Path $PSScriptRoot 'recovery/r10y_partial_direct_neutral_finite_cycle_contract_v1.json'
        $r10yTaskSha = 'sha256:' + (Get-FileHash -LiteralPath $r10yTaskPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($r10yTaskSha -cne 'sha256:3d78684470f51379955306c9bf717b5132711577c39422b8c04abe35d452f40c') { throw 'R10Y_HOST_DEADLINE_TASK' }
        $r10yTask = Get-Content -LiteralPath $r10yTaskPath -Raw | ConvertFrom-Json -AsHashtable
        $fields.timeout_seconds_per_child = $r10yTask.limits.child_wall_time_limit_seconds
        $fields.independent_replay_timeout_seconds = $r10yTask.limits.independent_reader_wall_time_limit_seconds
        $fields['r10y_development'] = $r10yDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10vSelected) {
        # The exact design owns the wall limit. This field is independently
        # reconstructed by the shared Python final-auditor declaration path.
        $r10vDesignPath = Join-Path $PSScriptRoot 'recovery/r10v_durable_workflow_design_v1.json'
        $r10vDesignSha = 'sha256:' + (Get-FileHash -LiteralPath $r10vDesignPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($r10vDesignSha -cne 'sha256:5903e0b69ac913f32d148246c6635bf9930b860defa1450a14d292d1473966ee' -or
            $r10vDevelopmentContext.design_binding.raw_sha256 -cne $r10vDesignSha) { throw 'R10V_HOST_DEADLINE_DESIGN' }
        $r10vDesign = Get-Content -LiteralPath $r10vDesignPath -Raw | ConvertFrom-Json -AsHashtable
        $fields.timeout_seconds_per_child = $r10vDesign.limits.per_child_wall_seconds
        $fields['r10v_development'] = $r10vDevelopmentContext
        if ($null -ne $script:R10VHostContext) { $fields['r10v_host'] = $script:R10VHostContext }
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10uSelected) {
        # The exact design owns the wall limit. This field is independently
        # reconstructed by the shared Python final-auditor declaration path.
        $r10uDesignPath = Join-Path $PSScriptRoot 'recovery/r10u_audit_handoff_design_v1.json'
        $r10uDesignSha = 'sha256:' + (Get-FileHash -LiteralPath $r10uDesignPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($r10uDesignSha -cne 'sha256:81f18c3e99929ee02c830f973c32c3db4fdb5917a5efa2863d59e5ee2a7fa981' -or
            $r10uDevelopmentContext.design_binding.raw_sha256 -cne $r10uDesignSha) { throw 'R10U_HOST_DEADLINE_DESIGN' }
        $r10uDesign = Get-Content -LiteralPath $r10uDesignPath -Raw | ConvertFrom-Json -AsHashtable
        $fields.timeout_seconds_per_child = $r10uDesign.limits.per_child_wall_seconds
        $fields['r10u_development'] = $r10uDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10tSelected) {
        $fields.timeout_seconds_per_child = 1740
        $fields['r10t_development'] = $r10tDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10sSelected) {
        $fields['r10s_development'] = $r10sDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10rSelected) {
        $fields['r10r_development'] = $r10rDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10qSelected) {
        $fields['r10q_development'] = $r10qDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10oSelected) {
        $fields['r10o_development'] = $r10oDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10nSelected) {
        $fields['r10n_development'] = $r10nDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10mSelected) {
        $fields['r10m_development'] = $r10mDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    if ($r10lSelected) {
        $fields['r10l_development'] = $r10lDevelopmentContext
        $fields['ledger_scope'] = @{subsystem='recovery';engine_scope='godot_jolt';authority_mode='bounded_development_diagnostic';question_class='development'}
    }
    return $fields
}

function Get-DevelopmentMeasuredEntryFields {
    $entryBinding = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development_passive_entry_runtime_binding_v1.json') -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    return [ordered]@{
        schema_version='sporespore_development_measured_prone_smoke_declaration_v1'
        diagnostic_schedule_id='measured_prone_entry_then_canonical_recovery_v1'
        maximum_passive_descent_steps=240; after_interaction_steps=480; maximum_steps_per_child=832
        timeout_seconds_per_child=1500; independent_replay_timeout_seconds=900
        passive_entry_runtime=$entryBinding.runtime
        runtime_selection_note='Original launch-foundation images remain bound; this worker unloads the default extension and selects passive_entry_runtime before SDK/model creation'
        coverage_question='Observe controller-free descent, measured-prone initialization, subsequent canonical recovery and any resumed walking inside one bounded post-kick tail'
        coverage_adequacy='One development seed and both fresh roles cover the new entry/ownership/energy/replay branch and untouched no-kick path. At 120 Hz: up to 2 seconds descent inside a 4 second total tail. The 25 minute child ceiling accommodates the observed roughly one-second-per-step development cost at the 832-step resource cap. Early terminal negatives remain valid diagnostics.'
        uncovered_paths=@('guaranteed completion of get-up or walking resume','full official walking horizon','held-out behavior','cross-engine effects','force-aware recovery')
    }
}
function Get-DevelopmentRearwardFoldFields {
    $selection = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development_rearward_fold_profile_v1.json') -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $bindingPath = $selection.worker_selection.binding.Replace('res://', '')
    $entryBinding = Get-Content -LiteralPath (Join-Path $repoRoot $bindingPath) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $fields = Get-DevelopmentMeasuredEntryFields
    $fields.schema_version = $selection.worker_selection.declaration_schema
    $fields.diagnostic_schedule_id = $selection.worker_selection.schedule
    $fields.passive_entry_runtime = $entryBinding.runtime
    $fields.coverage_question = 'Test fixed V7 front-leg rearward-fold support after measured prone; V6 setup and native measurement ancestry remain unchanged'
    return $fields
}
function Get-DevelopmentRateLimitedRecoveryFields {
    $selection = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development_rate_limited_recovery_profile_v1.json') -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $bindingPath = $selection.worker_selection.binding.Replace('res://', '')
    $entryBinding = Get-Content -LiteralPath (Join-Path $repoRoot $bindingPath) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $fields = Get-DevelopmentMeasuredEntryFields
    $fields.schema_version = $selection.worker_selection.declaration_schema
    $fields.diagnostic_schedule_id = $selection.worker_selection.schedule
    $fields.passive_entry_runtime = $entryBinding.runtime
    $fields.coverage_question = 'Test V8 four-rad/s support and rise target ceilings after measured prone; V7 targets, V6 setup, caps, phase rules and native measurement ancestry remain unchanged'
    return $fields
}
function Assert-R10KPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    # This is the production prelaunch check. The caller supplies only the
    # receipts just produced by the serialized stage loop on unchanged sources.
    $preparation = @($SelectedStages | Where-Object { $_.id -ceq 'r10k_preparation_report' })
    if ($preparation.Count -ne 1 -or $preparation[0].pattern -cne 'test_development_r10k_preparation_report.py' -or
        $preparation[0].tests -ne 2 -or $CompletedStages.Count -ne $SelectedStages.Count -or
        @($SelectedStages.id | Sort-Object -Unique).Count -ne $SelectedStages.Count) {
        throw 'R10K_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($stageIndex = 0; $stageIndex -lt $SelectedStages.Count; $stageIndex++) {
        $declaredStage = $SelectedStages[$stageIndex]
        $observedStage = $CompletedStages[$stageIndex]
        if ($observedStage.id -cne $declaredStage.id -or $observedStage.passed -isnot [bool] -or
            -not $observedStage.passed -or $observedStage.timed_out -isnot [bool] -or $observedStage.timed_out -or
            $observedStage.exit_code -ne 0 -or $observedStage.test_count -ne $declaredStage.tests -or
            $observedStage.expected_test_count -ne $declaredStage.tests) {
            throw 'R10K_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}

function Assert-R10VPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10v_safety_stage_contract_v3.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10v_safety_stage_contract_v3' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10V_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    # Local receipts use Int32; verified JSON-imported receipts use Int64.
    # Accept either integer representation without coercing floats or strings.
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -isnot [int] -or $selected.tests -ne $declared[$index].tests -or
            ($index -lt $contract.unbound_common_stage_count -and $selected.ContainsKey('candidate_profile')) -or
            ($index -ge $contract.unbound_common_stage_count -and $selected.candidate_profile -cne $candidatePathRequested) -or
            ($observed.test_count -isnot [int] -and $observed.test_count -isnot [long]) -or ($observed.expected_test_count -isnot [int] -and $observed.expected_test_count -isnot [long]) -or
            ($observed.exit_code -isnot [int] -and $observed.exit_code -isnot [long]) -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10V_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}
function Assert-R10UPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10u_safety_stage_contract_v4.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10u_safety_stage_contract_v4' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10U_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -isnot [int] -or $selected.tests -ne $declared[$index].tests -or
            ($index -lt $contract.unbound_common_stage_count -and $selected.ContainsKey('candidate_profile')) -or
            ($index -ge $contract.unbound_common_stage_count -and $selected.candidate_profile -cne $candidatePathRequested) -or
            $observed.test_count -isnot [int] -or $observed.expected_test_count -isnot [int] -or
            $observed.exit_code -isnot [int] -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10U_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}
function Assert-R10TPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10t_safety_stage_contract_v5.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10t_safety_stage_contract_v5' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10T_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -isnot [int] -or $selected.tests -ne $declared[$index].tests -or
            ($index -lt $contract.unbound_common_stage_count -and $selected.ContainsKey('candidate_profile')) -or
            ($index -ge $contract.unbound_common_stage_count -and $selected.candidate_profile -cne $candidatePathRequested) -or
            $observed.test_count -isnot [int] -or $observed.expected_test_count -isnot [int] -or
            $observed.exit_code -isnot [int] -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10T_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}
function Assert-R10SPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10s_safety_stage_contract_v2.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10s_safety_stage_contract_v2' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10S_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -isnot [int] -or $selected.tests -ne $declared[$index].tests -or
            ($index -lt $contract.unbound_common_stage_count -and $selected.ContainsKey('candidate_profile')) -or
            ($index -ge $contract.unbound_common_stage_count -and $selected.candidate_profile -cne $candidatePathRequested) -or
            $observed.test_count -isnot [int] -or $observed.expected_test_count -isnot [int] -or
            $observed.exit_code -isnot [int] -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10S_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}
function Assert-R10RPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10r_safety_stage_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10r_safety_stage_contract_v1' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10R_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -isnot [int] -or $selected.tests -ne $declared[$index].tests -or
            ($index -lt $contract.unbound_common_stage_count -and $selected.ContainsKey('candidate_profile')) -or
            ($index -ge $contract.unbound_common_stage_count -and $selected.candidate_profile -cne $candidatePathRequested) -or
            $observed.test_count -isnot [int] -or $observed.expected_test_count -isnot [int] -or
            $observed.exit_code -isnot [int] -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10R_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}
function Assert-R10QPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10q_safety_stage_contract_v3.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10q_safety_stage_contract_v3' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10Q_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -isnot [int] -or $selected.tests -ne $declared[$index].tests -or
            ($index -lt $contract.unbound_common_stage_count -and $selected.ContainsKey('candidate_profile')) -or
            ($index -ge $contract.unbound_common_stage_count -and $selected.candidate_profile -cne $candidatePathRequested) -or
            $observed.test_count -isnot [int] -or $observed.expected_test_count -isnot [int] -or
            $observed.exit_code -isnot [int] -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10Q_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}
function Assert-R10OPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10o_safety_stage_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10o_safety_stage_contract_v1' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10O_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -ne $declared[$index].tests -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10O_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}
function Assert-R10NPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10n_safety_stage_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10n_safety_stage_contract_v1' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10N_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -ne $declared[$index].tests -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10N_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}
function Assert-R10MPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10m_safety_stage_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10m_safety_stage_contract_v1' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10M_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        $declaredTimeout = if ($contract.stage_timeout_overrides_seconds.ContainsKey($selected.id)) { $contract.stage_timeout_overrides_seconds[$selected.id] } else { 180 }
        $selectedTimeout = if ($selected.ContainsKey('timeout_seconds')) { $selected.timeout_seconds } else { 180 }
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selectedTimeout -isnot [int] -or $selectedTimeout -ne $declaredTimeout -or
            $selected.tests -ne $declared[$index].tests -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10M_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}

function Assert-R10LPreparationSafety([object[]]$CompletedStages, [object[]]$SelectedStages) {
    $contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10l_safety_stage_contract_v1.json') -Raw | ConvertFrom-Json -AsHashtable
    $declared = @($contract.stages)
    if ($contract.schema_version -cne 'sporespore_r10l_safety_stage_contract_v1' -or
        $declared.Count -ne $SelectedStages.Count -or $CompletedStages.Count -ne $SelectedStages.Count) {
        throw 'R10L_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
    }
    for ($index = 0; $index -lt $declared.Count; $index++) {
        $selected = $SelectedStages[$index]
        $observed = $CompletedStages[$index]
        if ($selected.id -cne $declared[$index].id -or $selected.pattern -cne $declared[$index].pattern -or
            $selected.tests -ne $declared[$index].tests -or $observed.id -cne $selected.id -or
            $observed.passed -isnot [bool] -or -not $observed.passed -or
            $observed.timed_out -isnot [bool] -or $observed.timed_out -or $observed.exit_code -ne 0 -or
            $observed.test_count -ne $selected.tests -or $observed.expected_test_count -ne $selected.tests) {
            throw 'R10L_COMPLETE_PRODUCTION_SAFETY_GATE_PENDING'
        }
    }
}

if ($r10vHostRequestRequested) {
    if (-not $r10vSelected) { throw 'R10V_HOST_OPTIONS_REQUIRE_R10V_ROUTE' }
    $hostContextOutput=@(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10v_durable_host_v2.py') --context $r10vHostRequestRequested --supervisor-pid $PID)
    if ($LASTEXITCODE -ne 0 -or $hostContextOutput.Count -ne 1) { throw 'R10V_HOST_CONTEXT_REFUSED' }
    $script:R10VHostContext=$hostContextOutput[0] | ConvertFrom-Json -AsHashtable
    . (Join-Path $PSScriptRoot 'r10v_host_progress.ps1')
    Initialize-R10VHostProgress -RequestPath $r10vHostRequestRequested -Context $script:R10VHostContext
    if (-not $smokeLibraryRequested -and (($script:R10VHostContext.lane -notin @('production_gate','production_smoke')) -or
        $executeSmoke -ne ($script:R10VHostContext.lane -ceq 'production_smoke'))) { throw 'R10V_HOST_MODE_CROSSED' }
}
if ($r10vSelected -and -not $smokeLibraryRequested -and $null -eq $script:R10VHostContext) { throw 'R10V_DURABLE_HOST_REQUIRED' }
if ($smokeLibraryRequested) { return }
if ($r10apSelected -and $stages.Count -eq 0) { throw 'R10AP_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10amSelected -and $stages.Count -eq 0) { throw 'R10AM_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10ajSelected -and $stages.Count -eq 0) { throw 'R10AJ_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10aiSelected -and $stages.Count -eq 0) { throw 'R10AI_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10agSelected -and $stages.Count -eq 0) { throw 'R10AG_COMPLETE_SAFETY_CONTRACT_PENDING' } elseif ($r10afSelected -and $stages.Count -eq 0) { throw 'R10AF_COMPLETE_SAFETY_CONTRACT_PENDING' } elseif ($r10aeSelected -and $stages.Count -eq 0) { throw 'R10AE_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10adSelected -and $stages.Count -eq 0) { throw 'R10AD_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10acSelected -and $stages.Count -eq 0) { throw 'R10AC_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10abSelected -and $stages.Count -eq 0) { throw 'R10AB_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10aaSelected -and $stages.Count -eq 0) { throw 'R10AA_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10zSelected -and $stages.Count -eq 0) { throw 'R10Z_COMPLETE_SAFETY_CONTRACT_PENDING' }
if ($r10ySelected -and $stages.Count -eq 0) { throw 'R10Y_COMPLETE_SAFETY_CONTRACT_PENDING' }
$script:RepairId = 'QSDK-R10F-L15' # Selects implementation helpers, not an L15 campaign identity.
$script:PhysicalMarker = 'DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
$script:PhysicalAttemptId = if ($r10vSelected) { $script:R10VHostContext.attempt_id } else { [Guid]::NewGuid().ToString('N') }
$script:PhysicalAttemptRoot = Join-Path $evidenceRoot ('development-recovery-smoke-' + $script:PhysicalAttemptId)
$runRoot = $script:PhysicalAttemptRoot
$completed = [Collections.Generic.List[object]]::new()
$smokeLock = $null; $failure = ''; $source = $null; $audit = $null; $declaration = $null
$startedUtc = [DateTime]::UtcNow.ToString('o')
$physicalStarted = $false
try {
    $role = if ($executeSmoke) { 'physical_development' } else { 'conformance' }
    $smokeLock = Enter-SporeSporeLocomotionOperationLock -Role $role -TimeoutMilliseconds 0
    if (-not $smokeLock.acquired -or $smokeLock.abandoned_owner_recovered) { throw 'SMOKE_OPERATION_LOCK_BUSY' }
    $source = Get-DevelopmentSourceSnapshot
    $null = New-Item -ItemType Directory -Path $runRoot
    # Retain an early host/image refusal with zero completed stages and no child.
    $runtime = if ($r10apSelected) { Get-R10apRuntimeBinding -Godot $Godot } elseif ($r10amSelected) { Get-R10amRuntimeBinding -Godot $Godot } elseif ($r10ajSelected) { Get-R10ajRuntimeBinding -Godot $Godot } elseif ($r10aiSelected) { Get-R10aiRuntimeBinding -Godot $Godot } elseif ($r10agSelected) { Get-R10agRuntimeBinding -Godot $Godot } elseif ($r10afSelected) { Get-R10afRuntimeBinding -Godot $Godot } elseif ($r10aeSelected) { Get-R10aeRuntimeBinding -Godot $Godot } elseif ($r10adSelected) { Get-R10adRuntimeBinding -Godot $Godot } elseif ($r10acSelected) { Get-R10acRuntimeBinding -Godot $Godot } else { Get-QsdkR10fL14RuntimeBinding -Godot $Godot }
    if ($executeSmoke -and $r10apSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ap_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AP_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    elseif ($executeSmoke -and $r10amSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10am_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AM_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    elseif ($executeSmoke -and $r10ajSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aj_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AJ_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    elseif ($executeSmoke -and $r10aiSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ai_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AI_CLEAN_PUSHED_FREEZE_REQUIRED' }
    } elseif ($executeSmoke -and $r10agSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ag_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AG_CLEAN_PUSHED_FREEZE_REQUIRED' }
    } elseif ($executeSmoke -and $r10afSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10af_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AF_CLEAN_PUSHED_FREEZE_REQUIRED' }
    } elseif ($executeSmoke -and $r10aeSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ae_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AE_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10adSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ad_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AD_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10acSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ac_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AC_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10abSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ab_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AB_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10aaSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aa_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10AA_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10zSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10z_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10Z_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10ySelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10y_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10Y_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10vSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10v_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10V_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10uSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10u_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10U_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10tSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10t_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10T_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10sSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10s_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10S_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($executeSmoke -and $r10rSelected) {
        $freezeOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10r_development_launch.py') --check-freeze $source.head)
        if ($LASTEXITCODE -ne 0 -or $freezeOutput.Count -ne 1) { throw 'R10R_CLEAN_PUSHED_FREEZE_REQUIRED' }
    }
    if ($r10vSelected) {
        $hostRequestValue = Get-Content -LiteralPath $r10vHostRequestRequested -Raw | ConvertFrom-Json -AsHashtable
        $imported = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10v_prehost_qualification.py') --import-stages $hostRequestValue.prehost_qualification.path --target $runRoot)
        if ($LASTEXITCODE -ne 0 -or $imported.Count -ne 1) { throw 'R10V_PREHOST_IMPORT_REFUSED' }
        $r10vPrehostImported = $imported[0] | ConvertFrom-Json -AsHashtable
        Write-R10VHostProgress -Stage safety_gate -State start
    }
    foreach ($stage in $stages) {
        if ($r10vSelected -and $stage.id -in $r10vStageContract.prehost_stage_ids) {
            $result = @($r10vPrehostImported.stages | Where-Object { $_.id -ceq $stage.id })
            if ($result.Count -ne 1) { throw 'R10V_PREHOST_STAGE_MISSING' }
            $result = $result[0]
        } else { $result = Invoke-DevelopmentStage $stage $runRoot }
        $completed.Add($result)
        Write-Output ('DEVELOPMENT_SMOKE_STAGE ' + (ConvertTo-SporeSporeExactJson -Value $result))
        if (-not $result.passed) { throw ('SMOKE_SAFETY_GATE_FAILED:' + $stage.id) }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $source) -cne
        (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'SMOKE_SOURCE_CHANGED_DURING_GATE' }
    if ($r10vSelected) { Write-R10VHostProgress -Stage safety_gate -State end -Subject @{completed_stages=$completed.Count} }
    if ($executeSmoke) {
        if ($null -ne $r10vDevelopmentContext) {
            Assert-R10VPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10uDevelopmentContext) {
            Assert-R10UPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10tDevelopmentContext) {
            Assert-R10TPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10sDevelopmentContext) {
            Assert-R10SPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10rDevelopmentContext) {
            Assert-R10RPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10qDevelopmentContext) {
            Assert-R10QPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10oDevelopmentContext) {
            Assert-R10OPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10nDevelopmentContext) {
            Assert-R10NPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10mDevelopmentContext) {
            Assert-R10MPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10lDevelopmentContext) {
            Assert-R10LPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        if ($null -ne $r10kDevelopmentContext) {
            Assert-R10KPreparationSafety -CompletedStages $completed.ToArray() -SelectedStages $stages
        }
        $native = Get-OptionalSingleMarkerJson -Stdout ([IO.File]::ReadAllText(
            (Join-Path $runRoot 'smoke_native_safety.stdout.log'), [Text.UTF8Encoding]::new($false, $true))) `
            -Marker 'DEVELOPMENT_SMOKE_ZERO_WORLD '
        if ($null -eq $native -or $native.ok -isnot [bool] -or -not $native.ok) { throw 'SMOKE_NATIVE_CAPTURE_MISSING' }
        $capture = $native.native.l15_prepared_collection_context
        $prepared = ConvertFrom-Json -InputObject $capture.utf8_text -AsHashtable -Depth 100
        $expectation = @{
            raw_capture_binding = @{utf8_byte_length=$capture.utf8_byte_length;raw_sha256=$capture.raw_sha256}
            collection_identity = ConvertFrom-Json -InputObject $prepared.expected_identity.utf8_text -AsHashtable -Depth 100
        }
        $children = @($script:OrderedChildRoles | ForEach-Object {
            @{role=$_;child_attempt_id=[Guid]::NewGuid().ToString('N');termination_nonce=[Guid]::NewGuid().ToString('N');
              evidence_path=(Join-Path $runRoot ('children/' + $_))}
        })
        $declaration = [ordered]@{
            schema_version='sporespore_sdk1_development_recovery_smoke_declaration_v1'
            ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode='unofficial_physical_smoke';question_class='development'}
            attempt_id=$script:PhysicalAttemptId; source_snapshot=$source; runtime=$runtime
            seed=$script:DevelopmentSeed; children=$children; safety_stages=$completed.ToArray(); prepared_context_expectation=$expectation
            maximum_precondition_steps=320; walking_prefix_steps=30; interaction_steps=1; after_interaction_steps=30
            maximum_steps_per_child=382; timeout_seconds_per_child=$TimeoutSeconds
            coverage_question='Actual prone setup, walking handoff, kick/no-kick, offset collection, bounded stop and exact publication'
            uncovered_paths=@('full walking horizon','completed post-kick recovery and walking resume','held-out behavior','cross-engine effects')
            telemetry_profile='unchanged_full_per_step_capture'; official_qualification=$false
            physical_acceptance_authority=$false; release_authority=$false
        }
        if ($profileStepsRequested) {
            $declaration['step_cost_profile_id'] = 'recovery_step_cost_wall_clock_v1'
            $declaration['worker_resource'] = $script:WorkerResource
            $declaration['timing_scope'] = 'Monotonic wall time; nested sections subtract children; between-callback time is not isolated solver time'
        }
        if ($reuseContextChecksRequested) {
            $declaration['context_cache_profile_id'] = 'recovery_exact_context_checks_v1'
            $declaration['context_cache_call_sites'] = @('epoch_preflight', 'global_context_validation')
        }
        if ($observeProneDeadlineRequested) {
            $declaration['diagnostic_schedule_id'] = 'existing_prone_confirmation_deadline_v1'
            $declaration['after_interaction_steps'] = 60
            $declaration['maximum_steps_per_child'] = 412
            $declaration['coverage_question'] = 'Observe prone entry or the unchanged 60-step confirmation deadline; retain joint-limit flags and exact terminal propagation'
        }
        if ($observeMeasuredProneEntryRequested) {
            $entryFields = Get-DevelopmentMeasuredEntryFields
            foreach ($key in $entryFields.Keys) { $declaration[$key] = $entryFields[$key] }
        }
        if ($observeRearwardFoldRequested) {
            $entryFields = Get-DevelopmentRearwardFoldFields
            foreach ($key in $entryFields.Keys) { $declaration[$key] = $entryFields[$key] }
        }
        if ($observeRateLimitedRecoveryRequested) {
            $entryFields = Get-DevelopmentRateLimitedRecoveryFields
            foreach ($key in $entryFields.Keys) { $declaration[$key] = $entryFields[$key] }
        }
        if ($candidatePathRequested) {
            $entryFields = Get-DevelopmentCandidateFields
            foreach ($key in $entryFields.Keys) { $declaration[$key] = $entryFields[$key] }
        }
        if ($null -ne $r10kDevelopmentContext) { $declaration['r10k_development'] = $r10kDevelopmentContext }
        if ($r10apSelected) {
            # Produce from selected images before publishing the final declaration.
            $declaration.prepared_context_expectation = $null
            $proposalPath = Join-Path $runRoot 'r10ap_context_proposal.json'
            Write-JsonCreateNew $proposalPath $declaration
            $preparedOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ap_context_handoff.py') --prepare $proposalPath)
            if ($LASTEXITCODE -ne 0 -or $preparedOutput.Count -ne 1) { throw 'R10AP_CONTEXT_PRODUCTION_FAILED' }
            $prepared = $preparedOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            if ($prepared.ok -ne $true) { throw 'R10AP_CONTEXT_PRODUCTION_REFUSED' }
            $expectation = $prepared.expectation
            $declaration.prepared_context_expectation = $expectation
            $declaration['r10ap_context_producer'] = $prepared.producer
        }
        elseif ($r10amSelected) {
            # Produce from selected images before publishing the final declaration.
            $declaration.prepared_context_expectation = $null
            $proposalPath = Join-Path $runRoot 'r10am_context_proposal.json'
            Write-JsonCreateNew $proposalPath $declaration
            $preparedOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10am_context_handoff.py') --prepare $proposalPath)
            if ($LASTEXITCODE -ne 0 -or $preparedOutput.Count -ne 1) { throw 'R10AM_CONTEXT_PRODUCTION_FAILED' }
            $prepared = $preparedOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            if ($prepared.ok -ne $true) { throw 'R10AM_CONTEXT_PRODUCTION_REFUSED' }
            $expectation = $prepared.expectation
            $declaration.prepared_context_expectation = $expectation
            $declaration['r10am_context_producer'] = $prepared.producer
        }
        elseif ($r10ajSelected) {
            # Produce from selected images before publishing the final declaration.
            $declaration.prepared_context_expectation = $null
            $proposalPath = Join-Path $runRoot 'r10aj_context_proposal.json'
            Write-JsonCreateNew $proposalPath $declaration
            $preparedOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aj_context_handoff.py') --prepare $proposalPath)
            if ($LASTEXITCODE -ne 0 -or $preparedOutput.Count -ne 1) { throw 'R10AJ_CONTEXT_PRODUCTION_FAILED' }
            $prepared = $preparedOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            if ($prepared.ok -ne $true) { throw 'R10AJ_CONTEXT_PRODUCTION_REFUSED' }
            $expectation = $prepared.expectation
            $declaration.prepared_context_expectation = $expectation
            $declaration['r10aj_context_producer'] = $prepared.producer
        }
        elseif ($r10aiSelected) {
            # Produce from selected images before publishing the final declaration.
            $declaration.prepared_context_expectation = $null
            $proposalPath = Join-Path $runRoot 'r10ai_context_proposal.json'
            Write-JsonCreateNew $proposalPath $declaration
            $preparedOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ai_context_handoff.py') --prepare $proposalPath)
            if ($LASTEXITCODE -ne 0 -or $preparedOutput.Count -ne 1) { throw 'R10AI_CONTEXT_PRODUCTION_FAILED' }
            $prepared = $preparedOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            if ($prepared.ok -ne $true) { throw 'R10AI_CONTEXT_PRODUCTION_REFUSED' }
            $expectation = $prepared.expectation
            $declaration.prepared_context_expectation = $expectation
            $declaration['r10ai_context_producer'] = $prepared.producer
        } elseif ($r10agSelected) {
            # Produce from selected images before publishing the final declaration.
            $declaration.prepared_context_expectation = $null
            $proposalPath = Join-Path $runRoot 'r10ag_context_proposal.json'
            Write-JsonCreateNew $proposalPath $declaration
            $preparedOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ag_context_handoff.py') --prepare $proposalPath)
            if ($LASTEXITCODE -ne 0 -or $preparedOutput.Count -ne 1) { throw 'R10AG_CONTEXT_PRODUCTION_FAILED' }
            $prepared = $preparedOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            if ($prepared.ok -ne $true) { throw 'R10AG_CONTEXT_PRODUCTION_REFUSED' }
            $expectation = $prepared.expectation
            $declaration.prepared_context_expectation = $expectation
            $declaration['r10ag_context_producer'] = $prepared.producer
        } elseif ($r10afSelected) {
            # Produce from selected images before publishing the final declaration.
            $declaration.prepared_context_expectation = $null
            $proposalPath = Join-Path $runRoot 'r10af_context_proposal.json'
            Write-JsonCreateNew $proposalPath $declaration
            $preparedOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10af_context_handoff.py') --prepare $proposalPath)
            if ($LASTEXITCODE -ne 0 -or $preparedOutput.Count -ne 1) { throw 'R10AF_CONTEXT_PRODUCTION_FAILED' }
            $prepared = $preparedOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            if ($prepared.ok -ne $true) { throw 'R10AF_CONTEXT_PRODUCTION_REFUSED' }
            $expectation = $prepared.expectation
            $declaration.prepared_context_expectation = $expectation
            $declaration['r10af_context_producer'] = $prepared.producer
        } elseif ($r10aeSelected) {
            # Produce from selected images before publishing the final declaration.
            $declaration.prepared_context_expectation = $null
            $proposalPath = Join-Path $runRoot 'r10ae_context_proposal.json'
            Write-JsonCreateNew $proposalPath $declaration
            $preparedOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ae_context_handoff.py') --prepare $proposalPath)
            if ($LASTEXITCODE -ne 0 -or $preparedOutput.Count -ne 1) { throw 'R10AE_CONTEXT_PRODUCTION_FAILED' }
            $prepared = $preparedOutput[0] | ConvertFrom-Json -AsHashtable -Depth 100
            if ($prepared.ok -ne $true) { throw 'R10AE_CONTEXT_PRODUCTION_REFUSED' }
            $expectation = $prepared.expectation
            $declaration.prepared_context_expectation = $expectation
            $declaration['r10ae_context_producer'] = $prepared.producer
        }
        Write-JsonCreateNew (Join-Path $runRoot 'declaration.json') $declaration
        if ($r10apSelected) {
            # The same environment builder is used by the eventual physical child.
            $preWorldBinding = @{authority=@{source_commit=$source.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $runRoot 'declaration.json'));
                l14_exact_runtime_images=$runtime;l15_prepared_context_expectation=$expectation}
            $preWorldEnvironment = New-QsdkR10fL9ChildEnvironment -Descriptor $children[0] -Binding $preWorldBinding
            $environmentPath = Join-Path $runRoot 'r10ap_pre_world_environment.json'
            Write-JsonCreateNew $environmentPath $preWorldEnvironment
            $preWorldOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ap_context_handoff.py') --consume (Join-Path $runRoot 'declaration.json') --environment $environmentPath)
            if ($LASTEXITCODE -ne 0 -or $preWorldOutput.Count -ne 1 -or ($preWorldOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AP_PRE_WORLD_HANDOFF_REFUSED' }
        }
        elseif ($r10amSelected) {
            # The same environment builder is used by the eventual physical child.
            $preWorldBinding = @{authority=@{source_commit=$source.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $runRoot 'declaration.json'));
                l14_exact_runtime_images=$runtime;l15_prepared_context_expectation=$expectation}
            $preWorldEnvironment = New-QsdkR10fL9ChildEnvironment -Descriptor $children[0] -Binding $preWorldBinding
            $environmentPath = Join-Path $runRoot 'r10am_pre_world_environment.json'
            Write-JsonCreateNew $environmentPath $preWorldEnvironment
            $preWorldOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10am_context_handoff.py') --consume (Join-Path $runRoot 'declaration.json') --environment $environmentPath)
            if ($LASTEXITCODE -ne 0 -or $preWorldOutput.Count -ne 1 -or ($preWorldOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AM_PRE_WORLD_HANDOFF_REFUSED' }
        }
        elseif ($r10ajSelected) {
            # The same environment builder is used by the eventual physical child.
            $preWorldBinding = @{authority=@{source_commit=$source.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $runRoot 'declaration.json'));
                l14_exact_runtime_images=$runtime;l15_prepared_context_expectation=$expectation}
            $preWorldEnvironment = New-QsdkR10fL9ChildEnvironment -Descriptor $children[0] -Binding $preWorldBinding
            $environmentPath = Join-Path $runRoot 'r10aj_pre_world_environment.json'
            Write-JsonCreateNew $environmentPath $preWorldEnvironment
            $preWorldOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aj_context_handoff.py') --consume (Join-Path $runRoot 'declaration.json') --environment $environmentPath)
            if ($LASTEXITCODE -ne 0 -or $preWorldOutput.Count -ne 1 -or ($preWorldOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AJ_PRE_WORLD_HANDOFF_REFUSED' }
        }
        elseif ($r10aiSelected) {
            # The same environment builder is used by the eventual physical child.
            $preWorldBinding = @{authority=@{source_commit=$source.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $runRoot 'declaration.json'));
                l14_exact_runtime_images=$runtime;l15_prepared_context_expectation=$expectation}
            $preWorldEnvironment = New-QsdkR10fL9ChildEnvironment -Descriptor $children[0] -Binding $preWorldBinding
            $environmentPath = Join-Path $runRoot 'r10ai_pre_world_environment.json'
            Write-JsonCreateNew $environmentPath $preWorldEnvironment
            $preWorldOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ai_context_handoff.py') --consume (Join-Path $runRoot 'declaration.json') --environment $environmentPath)
            if ($LASTEXITCODE -ne 0 -or $preWorldOutput.Count -ne 1 -or ($preWorldOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AI_PRE_WORLD_HANDOFF_REFUSED' }
        } elseif ($r10agSelected) {
            # The same environment builder is used by the eventual physical child.
            $preWorldBinding = @{authority=@{source_commit=$source.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $runRoot 'declaration.json'));
                l14_exact_runtime_images=$runtime;l15_prepared_context_expectation=$expectation}
            $preWorldEnvironment = New-QsdkR10fL9ChildEnvironment -Descriptor $children[0] -Binding $preWorldBinding
            $environmentPath = Join-Path $runRoot 'r10ag_pre_world_environment.json'
            Write-JsonCreateNew $environmentPath $preWorldEnvironment
            $preWorldOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ag_context_handoff.py') --consume (Join-Path $runRoot 'declaration.json') --environment $environmentPath)
            if ($LASTEXITCODE -ne 0 -or $preWorldOutput.Count -ne 1 -or ($preWorldOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AG_PRE_WORLD_HANDOFF_REFUSED' }
        } elseif ($r10afSelected) {
            # The same environment builder is used by the eventual physical child.
            $preWorldBinding = @{authority=@{source_commit=$source.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $runRoot 'declaration.json'));
                l14_exact_runtime_images=$runtime;l15_prepared_context_expectation=$expectation}
            $preWorldEnvironment = New-QsdkR10fL9ChildEnvironment -Descriptor $children[0] -Binding $preWorldBinding
            $environmentPath = Join-Path $runRoot 'r10af_pre_world_environment.json'
            Write-JsonCreateNew $environmentPath $preWorldEnvironment
            $preWorldOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10af_context_handoff.py') --consume (Join-Path $runRoot 'declaration.json') --environment $environmentPath)
            if ($LASTEXITCODE -ne 0 -or $preWorldOutput.Count -ne 1 -or ($preWorldOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AF_PRE_WORLD_HANDOFF_REFUSED' }
        } elseif ($r10aeSelected) {
            # The same environment builder is used by the eventual physical child.
            $preWorldBinding = @{authority=@{source_commit=$source.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $runRoot 'declaration.json'));
                l14_exact_runtime_images=$runtime;l15_prepared_context_expectation=$expectation}
            $preWorldEnvironment = New-QsdkR10fL9ChildEnvironment -Descriptor $children[0] -Binding $preWorldBinding
            $environmentPath = Join-Path $runRoot 'r10ae_pre_world_environment.json'
            Write-JsonCreateNew $environmentPath $preWorldEnvironment
            $preWorldOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ae_context_handoff.py') --consume (Join-Path $runRoot 'declaration.json') --environment $environmentPath)
            if ($LASTEXITCODE -ne 0 -or $preWorldOutput.Count -ne 1 -or ($preWorldOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AE_PRE_WORLD_HANDOFF_REFUSED' }
        }
        if ($r10apSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ap_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AP_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        elseif ($r10amSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10am_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AM_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        elseif ($r10ajSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aj_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AJ_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        elseif ($r10aiSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ai_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AI_DEVELOPMENT_LAUNCH_REFUSED' }
        } elseif ($r10agSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ag_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AG_DEVELOPMENT_LAUNCH_REFUSED' }
        } elseif ($r10afSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10af_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AF_DEVELOPMENT_LAUNCH_REFUSED' }
        } elseif ($r10aeSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ae_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AE_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10adSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ad_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AD_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10acSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ac_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AC_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10abSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10ab_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AB_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10aaSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10aa_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10AA_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10zSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10z_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10Z_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10ySelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10y_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10Y_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10vSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10v_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10V_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10uSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10u_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10U_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10tSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10t_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10T_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10sSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10s_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10S_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        if ($r10rSelected) {
            $launchOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/r10r_development_launch.py') --authorize (Join-Path $runRoot 'declaration.json'))
            if ($LASTEXITCODE -ne 0 -or $launchOutput.Count -ne 1 -or ($launchOutput[0] | ConvertFrom-Json -AsHashtable).ok -ne $true) { throw 'R10R_DEVELOPMENT_LAUNCH_REFUSED' }
        }
        $binding = @{authority=@{source_commit=$source.head};authority_sha256=(Get-PrefixedSha256 (Join-Path $runRoot 'declaration.json'));
                     l14_exact_runtime_images=$runtime;l15_prepared_context_expectation=$expectation}
        foreach ($descriptor in $children) {
            if ((ConvertTo-SporeSporeExactJson -Value $source) -cne
                (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'SMOKE_SOURCE_CHANGED_BEFORE_CHILD' }
            $null = New-Item -ItemType Directory -Path $descriptor.evidence_path
            Write-JsonCreateNew (Join-Path $descriptor.evidence_path 'child_attempt_identity.json') $descriptor
            Write-Output ('DEVELOPMENT_SMOKE_CHILD_START ' + $descriptor.role)
            if ($r10vSelected) { Write-R10VHostProgress -Stage child -State start -Role $descriptor.role -Subject $descriptor }
            $physicalStarted = $true
            $child = Invoke-L9ChildProcess -Descriptor $descriptor -Binding $binding -GodotPath $Godot -RequireL15LaunchRelationship -RetainR10vCompactEnvelope:$r10vSelected -RetainR10yCompactEnvelope:$r10ySelected -RetainR10aaCompactEnvelope:$r10aaSelected -RetainR10abCompactEnvelope:$r10abSelected -RetainR10apCompactEnvelope:$r10apSelected -RetainR10amCompactEnvelope:$r10amSelected -RetainR10ajCompactEnvelope:$r10ajSelected -RetainR10aiCompactEnvelope:$r10aiSelected -RetainR10agCompactEnvelope:$r10agSelected -RetainR10afCompactEnvelope:$r10afSelected -RetainR10aeCompactEnvelope:$r10aeSelected -RetainR10adCompactEnvelope:$r10adSelected -RetainR10acCompactEnvelope:$r10acSelected -RetainR10zCompactEnvelope:$r10zSelected
            $launchContext = New-QsdkR10fL15ProductionLaunchContext $script:PhysicalAttemptId $descriptor $source.head $binding.authority_sha256 $runtime
            $null = Assert-QsdkR10fL15ChildLaunchRelationship $child $launchContext
            Write-Output ('DEVELOPMENT_SMOKE_CHILD_END ' + $descriptor.role + ' exit=' + $child.exit_code)
            if ($r10vSelected) { Write-R10VHostProgress -Stage child -State end -Role $descriptor.role -Subject @{child_attempt_id=$child.child_attempt_id;exit_code=$child.exit_code;envelope=$child.retained_envelope_binding;launch_relationship=$child.r10f_l15_launch_relationship} }
            if ($child.exit_code -ne 0 -or -not $child.raw_marker_valid -or -not $child.engine_health_passed) { throw ('SMOKE_CHILD_INVALID:' + $descriptor.role) }
        }
        if ($observeMeasuredProneEntryRequested -or $observeRearwardFoldRequested -or $observeRateLimitedRecoveryRequested -or $candidatePathRequested) {
            foreach ($descriptor in $children) {
                if ($r10vSelected) {
                    $hostProcess=Invoke-R10VHostPython -Arguments @((Join-Path $PSScriptRoot 'conformance/development_passive_entry_profile.py'),(Join-Path $descriptor.evidence_path 'worker_report.json'),'--run') -Stage replay -Role $descriptor.role -OutputBase (Join-Path $descriptor.evidence_path 'host_replay') -TimeoutSeconds 960
                    $replayOutput=$hostProcess.output; $replayExit=$hostProcess.exit_code
                } else {
                $replayOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/development_passive_entry_profile.py') `
                    (Join-Path $descriptor.evidence_path 'worker_report.json') --run)
                $replayExit = $LASTEXITCODE
                }
                Write-Utf8CreateNew (Join-Path $descriptor.evidence_path 'passive_entry_replay_result.json') (($replayOutput -join "`n") + "`n")
                if ($replayExit -ne 0 -or $replayOutput.Count -ne 1) { throw ('SMOKE_ENTRY_REPLAY_FAILED:' + $descriptor.role) }
            }
        }
        if ($r10vSelected) {
            $hostProcess=Invoke-R10VHostPython -Arguments @((Join-Path $PSScriptRoot 'conformance/development_recovery_smoke.py'),$runRoot) -Stage final_audit -Role '' -OutputBase (Join-Path $runRoot 'host_final_audit') -TimeoutSeconds 1800
            $auditOutput=$hostProcess.output; $auditExit=$hostProcess.exit_code
        } else {
        $auditOutput = @(& $pythonPath -B (Join-Path $PSScriptRoot 'conformance/development_recovery_smoke.py') $runRoot)
        $auditExit = $LASTEXITCODE
        }
        Write-Utf8CreateNew (Join-Path $runRoot 'independent_audit.stdout.json') (($auditOutput -join "`n") + "`n")
        if ($auditExit -ne 0 -or $auditOutput.Count -ne 1) { throw 'SMOKE_INDEPENDENT_AUDIT_FAILED' }
        $audit = ConvertFrom-Json -InputObject $auditOutput[0] -AsHashtable -Depth 100
        if ($audit.ok -isnot [bool] -or -not $audit.ok) { throw 'SMOKE_INDEPENDENT_AUDIT_REFUSED' }
    }
    if ((ConvertTo-SporeSporeExactJson -Value $source) -cne
        (ConvertTo-SporeSporeExactJson -Value (Get-DevelopmentSourceSnapshot))) { throw 'SMOKE_SOURCE_CHANGED_DURING_EXECUTION' }
} catch {
    $failure = $_.Exception.Message
} finally {
    if ($null -ne $smokeLock) { Exit-SporeSporeLocomotionOperationLock -Receipt $smokeLock }
}
$receipt = [ordered]@{
    schema_version='sporespore_sdk1_development_recovery_smoke_run_v1'
    ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode='unofficial_smoke_workflow';question_class='development'}
    ok=($failure -ceq ''); failure_code=$failure; run_smoke_requested=$executeSmoke
    physical_attempt_started=$physicalStarted; source_snapshot=$source; safety_stages=$completed.ToArray()
    children=@($script:ObservedChildEnvelopes | ForEach-Object {
        @{role=$_.role;child_attempt_id=$_.child_attempt_id;exit_code=$_.exit_code;
          envelope=(Get-R10fRetainedFileBinding (Join-Path $_.evidence_path 'child_envelope.json'))}
    }); independent_audit=$audit
    started_utc=$startedUtc;completed_utc=[DateTime]::UtcNow.ToString('o');output_root=$runRoot
    official_qualification_passed=$false;complete_route_proven=$false;behavioral_conclusion='none'
    physical_acceptance_authority=$false;release_authority=$false
}
if ($r10vSelected) { $receipt['r10v_host'] = $script:R10VHostContext }
if (Test-Path -LiteralPath $runRoot -PathType Container) {
    if ($r10vSelected) { Write-R10VHostProgress -Stage publication -State start }
    $path = Join-Path $runRoot 'supervisor_result.json'
    Write-JsonCreateNew $path $receipt
    $script:L15PrimaryReportBinding = Get-R10fRetainedFileBinding $path
    $script:L15PrimaryReportWriteCompleted = $true
    $published = @(Publish-L15SupervisorResult $receipt)
    if ($published.Count -ne 1) { throw 'SMOKE_PUBLISH_OUTPUT_COUNT' }
    Write-Utf8CreateNew (Join-Path $runRoot 'published_marker.txt') ($published[0] + "`n")
    Write-Output $published[0]
    if ($r10vSelected) { Write-R10VHostProgress -Stage publication -State end -Subject @{terminal=(Get-R10fRetainedFileBinding $path);marker=(Get-R10fRetainedFileBinding (Join-Path $runRoot 'published_marker.txt'))} }
} else { Write-Output ('DEVELOPMENT_RECOVERY_SMOKE_REFUSAL ' + $failure) }
if ($failure -cne '') { exit 1 }
