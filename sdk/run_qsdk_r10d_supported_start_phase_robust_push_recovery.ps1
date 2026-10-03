#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("ZeroWorld", "AuthorityCheck", "Physical")]
    [string]$Mode = "ZeroWorld",
    [ValidateSet("development_route_ghost", "held_out_finite_decision")]
    [string]$CampaignRole = "development_route_ghost",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$StageFreeze = "",
    [string]$ExecutionAuthority = "",
    [string]$Output = "",
    [ValidateRange(60, 1200)]
    [int]$CellTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$activeAdapterPath = [System.IO.Path]::GetFullPath(
    (Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll")
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$worker = "res://tests/test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_worker.gd"
$sourceTest = "res://tests/test_sdk_qsdk_r10d_supported_start_phase_robust_push_recovery_source.gd"
$sourceMarker = "QSDK_R10D_SUPPORTED_START_PHASE_ROBUST_PUSH_RECOVERY_SOURCE_ZERO_WORLD "
$contractMarker = "QSDK_R10D_WORKER_CONTRACT_ZERO_WORLD "
$preflightMarker = "QSDK_R10D_WORKER_ENTRYPOINT_ZERO_WORLD "
$cellMarker = "QSDK_R10D_PHYSICAL_CELL "
$pairMarker = "QSDK_R10D_PAIR_EVALUATION_ZERO_WORLD "
$repairId = "QSDK-R10D-L1"
$r10cDesignSha256 = "sha256:2f2a4f86562e3398d69fc08510c347ed1634a2331f45ce58651db7bbb8aae4a8"
$r10dL1DesignSha256 = "sha256:f98f9f057e6f583b6f0f356a983cdcbcb4d6818f217fe055edd96ddcbf326db3"
$consumedR10dPhysicalClosureSha256 = "sha256:fbefa85145bcd5bb05c3672c4fe6a0b56eaf75751ae8ed5dae9ff724487b4475"
$r10bHeldOutClosureSha256 = "sha256:108473a00fb7d789862996b85e95ef255cc62b5e2c6037aecb556bd77dce625a"
$r05ePhysicalClosureSha256 = "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
$attemptSchema = "sporespore_qsdk_r10d_physical_attempt_v2"
$authoritySchema = "sporespore_qsdk_r10d_execution_authority_v2"
$stageFreezeSchema = "sporespore_qsdk_r10d_stage_freeze_v2"
$runtimeProjectionSchema = "sporespore_qsdk_r10d_runtime_identity_projection_v1"
$runtimeIdentitySchema = "sporespore_qsdk_r10d_runtime_identity_v1"
$activeAdapterRelativePath = "sdk/target/debug/sporespore_godot_adapter.dll"
$qualifiedSourcePathCount = 88
$qualifiedSourcePathSha256 = "sha256:fde0b22bd6fbe0a51a07949efeb93550db16bdb580de39f192192f4d63c897e2"
$physicalCellSchema = "sporespore_qsdk_r10d_physical_cell_v2"
$worldEvaluationSchema = "sporespore_qsdk_r10d_world_evaluation_v1"
$pairEvaluationSchema = "sporespore_qsdk_r10d_pair_evaluation_v1"
$selectedCandidateId = "BW5R-B"
$selectedPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$selectedPolicyDigest = "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
$generatorIndex = 217
$morphologyId = "qsdk_r05e_axis_star_torso_length_low_s217"
$generatorReceiptSha256 = "sha256:21957689d0f3cca678c93da6993b8d6b48569f86114b3ce19df7e10cc7e1655e"
$r05eGeneratorReceiptSha256 = "sha256:776dc3efb497917a79391de6d895e4984d8c35fe9ae29b3470552e2ee3a087d9"
$r05eProportionSpecSha256 = "sha256:2ad58378a1e3c6e8e9b16a9862141c4f390f2947f01b1108cd66a594a0f75d0c"
$materialProfileId = "godot_jolt_bw5c_mu095_v1"
$fixtureSpecSha256 = "sha256:9b54fda516c11d451f319fb9ea116896de049aa53b43676de8745ca5f29d670a"
$controllerProfileSha256 = "sha256:e4fb8bc38d6892ec5d7a4b5eb01007ab7bdb405c69ddfccac1684889dadfba2b"
$materialProfileSha256 = "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
$adapterCapabilitySha256 = "sha256:f561944603b5b365804fbe12e9514355e71d12bfb45961b4f9499c47b52ec3cf"
$minimumNativeEffectMetersPerSecond = 1.0e-4
$campaign = if ($CampaignRole -ceq "development_route_ghost") {
    [ordered]@{
        id = "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        question_class = "development"
        seeds = @(40001)
        maximum_world_count = 2
        operation_role = "physical_development"
    }
} else {
    [ordered]@{
        id = "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-UPRIGHT-PUSH-RECOVERY-VALIDATION"
        question_class = "finite decision"
        seeds = @(40101, 40102, 40103)
        maximum_world_count = 6
        operation_role = "physical"
    }
}
$armOrder = @("matched_no_impulse_control", "lateral_upright_impulse")
$stageFreezeRelativePath = if ($CampaignRole -ceq "development_route_ghost") {
    "sdk/qsdk_r10d_development_route_ghost_zero_world_qualification_closure_v2.json"
} else {
    "sdk/qsdk_r10d_held_out_finite_decision_zero_world_qualification_closure_v2.json"
}
$executionAuthorityRelativePath = if ($CampaignRole -ceq "development_route_ghost") {
    "sdk/qsdk_r10d_development_route_ghost_execution_authority_v2.json"
} else {
    "sdk/qsdk_r10d_held_out_finite_decision_execution_authority_v2.json"
}
$r10cDesignRelativePath = "sdk/qsdk_r10c_supported_start_phase_robust_successor_design_v1.json"
$r10dL1DesignRelativePath = "sdk/qsdk_r10d_l1_stage_freeze_numeric_normalization_successor_design_v1.json"
$consumedR10dPhysicalClosureRelativePath = "sdk/qsdk_r10d_development_route_ghost_physical_closure_v1.json"
$r10bHeldOutClosureRelativePath = "sdk/qsdk_r10b_held_out_finite_decision_physical_closure_v1.json"
$r05ePhysicalClosureRelativePath = "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json"
$evidenceRoot = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable is missing: $godotPath"
}
if (-not (Test-Path -LiteralPath $activeAdapterPath -PathType Leaf)) {
    throw "The active Godot adapter is missing: $activeAdapterPath"
}
if (-not (Test-Path -LiteralPath $operationLockPath -PathType Leaf)) {
    throw "The shared locomotion operation lock is missing"
}
. $operationLockPath

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-TextSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $digest = [Security.Cryptography.SHA256]::HashData($bytes)
    return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
}

function Get-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [switch]$AllowEmpty
    )
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R10D Git check failed: $Label"
    }
    $value = (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($value)) {
        throw "QSDK-R10D Git check was empty: $Label"
    }
    return $value
}

function Test-LowerHex {
    param([string]$Value, [int]$Length)
    return $Value.Length -eq $Length -and $Value -cmatch "^[0-9a-f]+$"
}

function Test-ExactStringArray {
    param([object[]]$Actual, [string[]]$Expected)
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ([string]$Actual[$index] -cne $Expected[$index]) { return $false }
    }
    return $true
}

function Test-StrictOrdinalStringOrder {
    param([object[]]$Values)
    for ($index = 1; $index -lt $Values.Count; $index++) {
        if (
            [StringComparer]::Ordinal.Compare(
                [string]$Values[$index - 1],
                [string]$Values[$index]
            ) -ge 0
        ) {
            return $false
        }
    }
    return $true
}

function Assert-RequiredReceiptKeys {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)]
        [string[]]$Keys,
        [Parameter(Mandatory)]
        [string]$Label
    )
    foreach ($key in $Keys) {
        if (-not $Receipt.Contains($key)) {
            throw "$Label is missing required field '$key'"
        }
    }
}

function Test-FiniteNumber {
    param([object]$Value)
    if ($null -eq $Value) { return $false }
    try {
        $number = [double]$Value
    } catch {
        return $false
    }
    return -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)
}

function Test-PrefixedSha256 {
    param([string]$Value)
    return (
        $Value.Length -eq 71 -and
        $Value.StartsWith("sha256:", [StringComparison]::Ordinal) -and
        (Test-LowerHex -Value $Value.Substring(7) -Length 64)
    )
}

function ConvertTo-CanonicalJsonValue {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        [string[]]$keys = @($Value.Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        foreach ($key in $keys) {
            $result[$key] = ConvertTo-CanonicalJsonValue -Value $Value[$key]
        }
        return $result
    }
    if (
        $Value -is [System.Collections.IEnumerable] -and
        $Value -isnot [string]
    ) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            $items.Add((ConvertTo-CanonicalJsonValue -Value $item))
        }
        return ,$items.ToArray()
    }
    return $Value
}

function Assert-QualifiedRuntimeCurrent {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$RuntimeProjection
    )
    Assert-RequiredReceiptKeys -Receipt $RuntimeProjection -Keys @(
        "schema_version", "identity_sha256", "identity"
    ) -Label "R10D qualified runtime projection"
    $identity = $RuntimeProjection.identity
    if ($identity -isnot [System.Collections.IDictionary]) {
        throw "R10D qualified runtime identity is not an object"
    }
    Assert-RequiredReceiptKeys -Receipt $identity -Keys @(
        "schema_version", "godot", "active_adapter", "python",
        "powershell", "git", "cargo", "gdformat"
    ) -Label "R10D qualified runtime identity"
    if (
        [string]$RuntimeProjection.schema_version -cne $runtimeProjectionSchema -or
        [string]$identity.schema_version -cne $runtimeIdentitySchema -or
        -not (Test-PrefixedSha256 -Value ([string]$RuntimeProjection.identity_sha256))
    ) {
        throw "R10D qualified runtime projection schema or digest is invalid"
    }

    $canonicalIdentity = ConvertTo-CanonicalJsonValue -Value $identity
    $canonicalJson = ConvertTo-Json -InputObject $canonicalIdentity -Depth 100 -Compress
    if (
        (Get-TextSha256 -Text $canonicalJson) -cne
        [string]$RuntimeProjection.identity_sha256
    ) {
        throw "R10D qualified runtime identity digest is invalid"
    }

    foreach ($toolName in @("godot", "python", "powershell", "git", "cargo", "gdformat")) {
        $tool = $identity[$toolName]
        if ($tool -isnot [System.Collections.IDictionary]) {
            throw "R10D qualified runtime tool identity is invalid: $toolName"
        }
        Assert-RequiredReceiptKeys -Receipt $tool -Keys @(
            "path", "raw_sha256", "byte_length", "version"
        ) -Label "R10D qualified runtime tool $toolName"
        if (
            -not [System.IO.Path]::IsPathFullyQualified([string]$tool.path) -or
            -not (Test-PrefixedSha256 -Value ([string]$tool.raw_sha256)) -or
            [int64]$tool.byte_length -le 0 -or
            [string]::IsNullOrWhiteSpace([string]$tool.version)
        ) {
            throw "R10D qualified runtime tool fields are invalid: $toolName"
        }
    }

    $qualifiedGodot = $identity.godot
    $qualifiedAdapter = $identity.active_adapter
    if ($qualifiedAdapter -isnot [System.Collections.IDictionary]) {
        throw "R10D qualified active adapter identity is invalid"
    }
    Assert-RequiredReceiptKeys -Receipt $qualifiedAdapter -Keys @(
        "path", "raw_sha256", "byte_length"
    ) -Label "R10D qualified active adapter"
    if (
        [System.IO.Path]::GetFullPath([string]$qualifiedGodot.path) -cne $godotPath -or
        [string]$qualifiedGodot.raw_sha256 -cne (Get-PrefixedSha256 $godotPath) -or
        [int64]$qualifiedGodot.byte_length -ne
            [int64](Get-Item -LiteralPath $godotPath).Length -or
        [string]$qualifiedAdapter.path -cne $activeAdapterRelativePath -or
        -not (Test-PrefixedSha256 -Value ([string]$qualifiedAdapter.raw_sha256)) -or
        [string]$qualifiedAdapter.raw_sha256 -cne (Get-PrefixedSha256 $activeAdapterPath) -or
        [int64]$qualifiedAdapter.byte_length -ne
            [int64](Get-Item -LiteralPath $activeAdapterPath).Length
    ) {
        throw "The qualified Godot or native adapter runtime has drifted"
    }
    return [ordered]@{
        runtime_identity_sha256 = [string]$RuntimeProjection.identity_sha256
        godot_path = $godotPath
        godot_raw_sha256 = [string]$qualifiedGodot.raw_sha256
        godot_byte_length = [int64]$qualifiedGodot.byte_length
        active_adapter_path = $activeAdapterRelativePath
        active_adapter_raw_sha256 = [string]$qualifiedAdapter.raw_sha256
        active_adapter_byte_length = [int64]$qualifiedAdapter.byte_length
    }
}

function Assert-PhysicalCellReceipt {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)]
        [string]$ExpectedArmId,
        [Parameter(Mandatory)]
        [int]$ExpectedSeed,
        [Parameter(Mandatory)]
        [string]$ExpectedCellId,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$QualifiedAuthority,
        [Parameter(Mandatory)]
        [string]$AttemptPath
    )
    Assert-RequiredReceiptKeys -Receipt $Receipt -Label "physical cell $ExpectedCellId" -Keys @(
        "schema_version", "gate_id", "repair_id", "campaign_id", "campaign_role",
        "source_commit", "arm_id", "campaign_seed", "cell_id",
        "selected_candidate_id", "controller_policy_id", "selected_policy_digest",
        "generator_index", "morphology_id", "generator_receipt_sha256",
        "source_r05e_generator_receipt_sha256", "proportion_spec_sha256",
        "material_profile_id", "material_profile_sha256", "r10c_design_sha256",
        "r10d_l1_design_sha256", "consumed_r10d_physical_closure_sha256",
        "consumed_r10b_held_out_closure_sha256", "r05e_physical_closure_sha256",
        "fixture_spec_sha256", "controller_profile_sha256", "adapter_capability_sha256",
        "authorization", "evaluation", "runtime_summary_projection", "sdk_physical_trace",
        "world_build_count", "world_reset_count", "behavior_passed", "outcome_complete",
        "evidence_valid", "physical_acceptance_authority", "release_authority"
    )
    $topLevelExact = (
        [string]$Receipt.schema_version -ceq $physicalCellSchema -and
        [string]$Receipt.gate_id -ceq "QSDK-R10D" -and
        [string]$Receipt.repair_id -ceq $repairId -and
        [string]$Receipt.campaign_id -ceq [string]$campaign.id -and
        [string]$Receipt.campaign_role -ceq $CampaignRole -and
        [string]$Receipt.source_commit -ceq [string]$QualifiedAuthority.source_commit -and
        [string]$Receipt.arm_id -ceq $ExpectedArmId -and
        [int]$Receipt.campaign_seed -eq $ExpectedSeed -and
        [string]$Receipt.cell_id -ceq $ExpectedCellId -and
        [string]$Receipt.selected_candidate_id -ceq $selectedCandidateId -and
        [string]$Receipt.controller_policy_id -ceq $selectedPolicyId -and
        [string]$Receipt.selected_policy_digest -ceq $selectedPolicyDigest -and
        [int]$Receipt.generator_index -eq $generatorIndex -and
        [string]$Receipt.morphology_id -ceq $morphologyId -and
        [string]$Receipt.generator_receipt_sha256 -ceq $generatorReceiptSha256 -and
        [string]$Receipt.source_r05e_generator_receipt_sha256 -ceq $r05eGeneratorReceiptSha256 -and
        [string]$Receipt.proportion_spec_sha256 -ceq $r05eProportionSpecSha256 -and
        [string]$Receipt.material_profile_id -ceq $materialProfileId -and
        [string]$Receipt.material_profile_sha256 -ceq $materialProfileSha256 -and
        [string]$Receipt.r10c_design_sha256 -ceq $r10cDesignSha256 -and
        [string]$Receipt.r10d_l1_design_sha256 -ceq $r10dL1DesignSha256 -and
        [string]$Receipt.consumed_r10d_physical_closure_sha256 -ceq
            $consumedR10dPhysicalClosureSha256 -and
        [string]$Receipt.consumed_r10b_held_out_closure_sha256 -ceq $r10bHeldOutClosureSha256 -and
        [string]$Receipt.r05e_physical_closure_sha256 -ceq $r05ePhysicalClosureSha256 -and
        [string]$Receipt.fixture_spec_sha256 -ceq $fixtureSpecSha256 -and
        [string]$Receipt.controller_profile_sha256 -ceq $controllerProfileSha256 -and
        [string]$Receipt.adapter_capability_sha256 -ceq $adapterCapabilitySha256 -and
        [int]$Receipt.world_build_count -eq 1 -and
        [int]$Receipt.world_reset_count -eq 0 -and
        $Receipt.behavior_passed -is [bool] -and
        [bool]$Receipt.outcome_complete -and
        [bool]$Receipt.evidence_valid -and
        -not [bool]$Receipt.physical_acceptance_authority -and
        -not [bool]$Receipt.release_authority
    )
    if (-not $topLevelExact) {
        throw "Physical cell $ExpectedCellId did not match its exact frozen identity"
    }
    $attemptDocument = Get-Content -LiteralPath $AttemptPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-RequiredReceiptKeys -Receipt $attemptDocument `
        -Label "physical attempt for $ExpectedCellId" -Keys @(
            "runtime_identity_sha256", "godot_raw_sha256", "godot_byte_length",
            "active_adapter_raw_sha256", "active_adapter_byte_length"
        )
    if (
        [string]$attemptDocument.runtime_identity_sha256 -cne
            [string]$QualifiedAuthority.runtime_identity_sha256 -or
        [string]$attemptDocument.godot_raw_sha256 -cne
            [string]$QualifiedAuthority.godot_raw_sha256 -or
        [int64]$attemptDocument.godot_byte_length -ne
            [int64]$QualifiedAuthority.godot_byte_length -or
        [string]$attemptDocument.active_adapter_raw_sha256 -cne
            [string]$QualifiedAuthority.active_adapter_raw_sha256 -or
        [int64]$attemptDocument.active_adapter_byte_length -ne
            [int64]$QualifiedAuthority.active_adapter_byte_length
    ) {
        throw "Physical cell $ExpectedCellId attempt lost its qualified runtime identity"
    }

    if (
        $Receipt.authorization -isnot [System.Collections.IDictionary] -or
        $Receipt.evaluation -isnot [System.Collections.IDictionary] -or
        $Receipt.runtime_summary_projection -isnot [System.Collections.IDictionary] -or
        $Receipt.sdk_physical_trace -isnot [System.Collections.IDictionary]
    ) {
        throw "Physical cell $ExpectedCellId omitted a required receipt object"
    }
    $authorization = $Receipt.authorization
    $evaluation = $Receipt.evaluation
    $runtime = $Receipt.runtime_summary_projection
    $trace = $Receipt.sdk_physical_trace
    Assert-RequiredReceiptKeys -Receipt $authorization -Label "authorization for $ExpectedCellId" -Keys @(
        "ok", "failure_code", "campaign_id", "repair_id", "campaign_role", "arm_id", "campaign_seed",
        "cell_id", "source_commit", "authorization_commit", "authorization_parent_commit",
        "qualification_parent_commit", "attempt_path", "attempt_sha256", "stage_freeze_path",
        "stage_freeze_sha256", "execution_authority_path", "execution_authority_sha256",
        "output_root", "world_build_count", "physical_acceptance_authority"
    )
    $authorizationExact = (
        [bool]$authorization.ok -and
        [string]$authorization.failure_code -ceq "" -and
        [string]$authorization.campaign_id -ceq [string]$campaign.id -and
        [string]$authorization.repair_id -ceq $repairId -and
        [string]$authorization.campaign_role -ceq $CampaignRole -and
        [string]$authorization.arm_id -ceq $ExpectedArmId -and
        [int]$authorization.campaign_seed -eq $ExpectedSeed -and
        [string]$authorization.cell_id -ceq $ExpectedCellId -and
        [string]$authorization.source_commit -ceq [string]$QualifiedAuthority.source_commit -and
        [string]$authorization.authorization_commit -ceq [string]$QualifiedAuthority.authorization_commit -and
        [string]$authorization.authorization_parent_commit -ceq [string]$QualifiedAuthority.qualification_commit -and
        [string]$authorization.qualification_parent_commit -ceq [string]$QualifiedAuthority.qualification_parent_commit -and
        [string]$authorization.attempt_path -ceq $AttemptPath -and
        [string]$authorization.attempt_sha256 -ceq (Get-PrefixedSha256 $AttemptPath) -and
        [string]$authorization.stage_freeze_path -ceq [string]$QualifiedAuthority.stage_freeze_path -and
        [string]$authorization.stage_freeze_sha256 -ceq [string]$QualifiedAuthority.stage_freeze_sha256 -and
        [string]$authorization.execution_authority_path -ceq [string]$QualifiedAuthority.execution_authority_path -and
        [string]$authorization.execution_authority_sha256 -ceq [string]$QualifiedAuthority.execution_authority_sha256 -and
        [string]$authorization.output_root -ceq [string]$QualifiedAuthority.output_root -and
        [int]$authorization.world_build_count -eq 0 -and
        -not [bool]$authorization.physical_acceptance_authority
    )
    if (-not $authorizationExact) {
        throw "Physical cell $ExpectedCellId did not preserve its exact authorization chain"
    }

    Assert-RequiredReceiptKeys -Receipt $evaluation -Label "evaluation for $ExpectedCellId" -Keys @(
        "schema_version", "gate_id", "repair_id", "ok", "failure_code", "outcome_complete",
        "evidence_valid", "behavior_passed", "arm_id", "campaign_seed", "cell_id",
        "sdk_step_count", "trace_row_count", "common_execution_integrity",
        "walking_receipts_structurally_complete", "application_receipt",
        "initial_perturbation_sha256", "evaluation_world_build_count",
        "physical_acceptance_authority", "release_authority"
    )
    $evaluationExact = (
        [string]$evaluation.schema_version -ceq $worldEvaluationSchema -and
        [string]$evaluation.gate_id -ceq "QSDK-R10D" -and
        [string]$evaluation.repair_id -ceq $repairId -and
        [bool]$evaluation.ok -and
        [string]$evaluation.failure_code -ceq "" -and
        [bool]$evaluation.outcome_complete -and
        [bool]$evaluation.evidence_valid -and
        $evaluation.behavior_passed -is [bool] -and
        [bool]$evaluation.behavior_passed -eq [bool]$Receipt.behavior_passed -and
        [string]$evaluation.arm_id -ceq $ExpectedArmId -and
        [int]$evaluation.campaign_seed -eq $ExpectedSeed -and
        [string]$evaluation.cell_id -ceq $ExpectedCellId -and
        [int]$evaluation.sdk_step_count -ge 2152 -and
        [int]$evaluation.sdk_step_count -le 2872 -and
        [int]$evaluation.trace_row_count -eq [int]$evaluation.sdk_step_count -and
        [bool]$evaluation.common_execution_integrity -and
        [bool]$evaluation.walking_receipts_structurally_complete -and
        (Test-PrefixedSha256 -Value ([string]$evaluation.initial_perturbation_sha256)) -and
        [int]$evaluation.evaluation_world_build_count -eq 0 -and
        -not [bool]$evaluation.physical_acceptance_authority -and
        -not [bool]$evaluation.release_authority
    )
    if (-not $evaluationExact) {
        throw "Physical cell $ExpectedCellId did not preserve its exact evaluator result"
    }

    Assert-RequiredReceiptKeys -Receipt $runtime -Label "runtime projection for $ExpectedCellId" -Keys @(
        "ok", "failure_code", "physical_wave_gait_walking_observed", "world_build_count",
        "world_reset_count", "executed_ticks", "sdk_adapter_start_tick", "physics_engine",
        "physics_hz", "solver_velocity_steps", "solver_position_steps", "fixture_spec_sha256",
        "sdk_material_profile_sha256", "initial_perturbation", "environment_challenge_options",
        "environment_challenge_configuration_sha256", "external_push_application_count",
        "external_push_receipt", "walking_gate_receipts", "sdk_authority_summary"
    )
    if (
        [bool]$runtime.ok -ne [bool]$runtime.physical_wave_gait_walking_observed -or
        [int]$runtime.world_build_count -ne 1 -or
        [int]$runtime.world_reset_count -ne 0 -or
        [string]$runtime.physics_engine -cne "Jolt Physics" -or
        [int]$runtime.physics_hz -ne 120 -or
        [int]$runtime.solver_velocity_steps -ne 20 -or
        [int]$runtime.solver_position_steps -ne 7 -or
        [string]$runtime.fixture_spec_sha256 -cne $fixtureSpecSha256 -or
        [string]$runtime.sdk_material_profile_sha256 -cne $materialProfileSha256 -or
        $runtime.external_push_receipt -isnot [System.Collections.IDictionary]
    ) {
        throw "Physical cell $ExpectedCellId did not preserve its exact native runtime projection"
    }

    Assert-RequiredReceiptKeys -Receipt $trace -Label "physical trace for $ExpectedCellId" -Keys @(
        "schema_version", "enabled", "options", "configuration_sha256", "row_count",
        "failure_codes", "rows", "world_build_count", "physical_acceptance_authority"
    )
    if ($trace.options -isnot [System.Collections.IDictionary]) {
        throw "Physical cell $ExpectedCellId omitted its exact trace options"
    }
    $traceOptions = $trace.options
    $traceRows = @($trace.rows)
    $traceFailures = @($trace.failure_codes)
    if (
        [string]$trace.schema_version -cne "sporespore_sdk_physical_trace_v1" -or
        -not [bool]$trace.enabled -or
        [string]$traceOptions.cell_id -cne $ExpectedCellId -or
        [string]$traceOptions.policy_id -cne "qsdk_r10d_supported_start_phase_robust_push_recovery_trace_v1" -or
        [string]$traceOptions.trace_row_schema_version -cne "sporespore_qsdk_r10d_supported_start_phase_robust_push_recovery_trace_row_v1" -or
        [int]$traceOptions.minimum_controller_step_count -ne 2152 -or
        [int]$traceOptions.maximum_controller_step_count -ne 2872 -or
        [int]$traceOptions.push_marker_semantic_step -ne 900 -or
        [string]$traceOptions.sampling_phase -cne "post_physics_for_applied_semantic_step" -or
        -not [bool]$traceOptions.enabled -or
        -not (Test-PrefixedSha256 -Value ([string]$trace.configuration_sha256)) -or
        [int]$trace.row_count -ne [int]$evaluation.sdk_step_count -or
        $traceRows.Count -ne [int]$evaluation.sdk_step_count -or
        $traceFailures.Count -ne 0 -or
        [int]$trace.world_build_count -ne 1 -or
        [bool]$trace.physical_acceptance_authority
    ) {
        throw "Physical cell $ExpectedCellId did not retain its exact complete trace"
    }

    $application = $evaluation.application_receipt
    $externalPush = $runtime.external_push_receipt
    if (
        $application -isnot [System.Collections.IDictionary] -or
        $externalPush -isnot [System.Collections.IDictionary]
    ) {
        throw "Physical cell $ExpectedCellId omitted its native impulse receipts"
    }
    if ($ExpectedArmId -ceq "matched_no_impulse_control") {
        if (
            [int]$runtime.external_push_application_count -ne 0 -or
            $externalPush.Count -ne 0 -or
            [int]$application.application_count -ne 0 -or
            [bool]$application.effect_sampled -or
            [double]$application.effect_magnitude_m_s -ne 0.0
        ) {
            throw "Baseline cell $ExpectedCellId was not an exact no-impulse control"
        }
    } else {
        $impulseTask = @($externalPush.impulse_task_n_s)
        $observedDelta = @($application.observed_velocity_delta_world_m_s)
        if (
            [int]$runtime.external_push_application_count -ne 1 -or
            [string]$externalPush.profile_id -cne "lateral_impulse_v1" -or
            [string]$externalPush.target_body_id -cne "torso" -or
            [string]$externalPush.application_method -cne "RigidBody3D.apply_central_impulse" -or
            [int]$externalPush.step_from_sdk_start -ne 900 -or
            [int]$externalPush.application_count -ne 1 -or
            [bool]$externalPush.controller_command -or
            -not [bool]$externalPush.effect_sampled -or
            $impulseTask.Count -ne 3 -or
            [double]$impulseTask[0] -ne 0.0 -or
            [double]$impulseTask[1] -ne 0.0 -or
            [double]$impulseTask[2] -ne 0.25 -or
            [int]$application.application_count -ne 1 -or
            [string]$application.profile_id -cne "lateral_impulse_v1" -or
            [int]$application.step_from_sdk_start -ne 900 -or
            -not [bool]$application.effect_sampled -or
            -not (Test-FiniteNumber $application.effect_magnitude_m_s) -or
            [double]$application.effect_magnitude_m_s -le $minimumNativeEffectMetersPerSecond -or
            $observedDelta.Count -ne 3 -or
            -not (Test-FiniteNumber $observedDelta[0]) -or
            -not (Test-FiniteNumber $observedDelta[1]) -or
            -not (Test-FiniteNumber $observedDelta[2])
        ) {
            throw "Push cell $ExpectedCellId did not prove the exact native torso impulse path"
        }
    }
}

function Assert-PairReceipt {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)]
        [int]$ExpectedSeed,
        [Parameter(Mandatory)]
        [string]$BaselineCellSha256,
        [Parameter(Mandatory)]
        [string]$PushCellSha256,
        [Parameter(Mandatory)]
        [bool]$BaselineBehaviorPassed,
        [Parameter(Mandatory)]
        [bool]$PushBehaviorPassed
    )
    Assert-RequiredReceiptKeys -Receipt $Receipt -Label "pair s$ExpectedSeed" -Keys @(
        "schema_version", "gate_id", "repair_id", "ok", "failure_code", "outcome_complete",
        "evidence_valid", "behavior_passed", "campaign_seed", "baseline_cell_id",
        "push_cell_id", "matched_initial_perturbation", "native_effect_magnitude_m_s",
        "paired_lateral_velocity_jump_difference_m_s", "native_effect_confirmed",
        "baseline_behavior_passed", "push_behavior_passed", "baseline_cell_raw_sha256",
        "push_cell_raw_sha256", "evaluation_world_build_count", "model_construction_count",
        "world_attempt_count", "world_build_count", "scene_tree_insertion_count",
        "native_readback_count", "solver_step_count", "physics_state_modified",
        "physical_acceptance_authority", "release_authority"
    )
    $baselineCellId = Get-CellId -ArmId "matched_no_impulse_control" -Seed $ExpectedSeed
    $pushCellId = Get-CellId -ArmId "lateral_upright_impulse" -Seed $ExpectedSeed
    $expectedBehaviorPassed = $BaselineBehaviorPassed -and $PushBehaviorPassed
    $exact = (
        [string]$Receipt.schema_version -ceq $pairEvaluationSchema -and
        [string]$Receipt.gate_id -ceq "QSDK-R10D" -and
        [string]$Receipt.repair_id -ceq $repairId -and
        [bool]$Receipt.ok -and
        [string]$Receipt.failure_code -ceq "" -and
        [bool]$Receipt.outcome_complete -and
        [bool]$Receipt.evidence_valid -and
        $Receipt.behavior_passed -is [bool] -and
        [bool]$Receipt.behavior_passed -eq $expectedBehaviorPassed -and
        [int]$Receipt.campaign_seed -eq $ExpectedSeed -and
        [string]$Receipt.baseline_cell_id -ceq $baselineCellId -and
        [string]$Receipt.push_cell_id -ceq $pushCellId -and
        [bool]$Receipt.matched_initial_perturbation -and
        [string]$Receipt.baseline_cell_raw_sha256 -ceq $BaselineCellSha256 -and
        [string]$Receipt.push_cell_raw_sha256 -ceq $PushCellSha256 -and
        (Test-FiniteNumber $Receipt.native_effect_magnitude_m_s) -and
        [double]$Receipt.native_effect_magnitude_m_s -gt $minimumNativeEffectMetersPerSecond -and
        (Test-FiniteNumber $Receipt.paired_lateral_velocity_jump_difference_m_s) -and
        [double]$Receipt.paired_lateral_velocity_jump_difference_m_s -gt 0.0 -and
        [bool]$Receipt.native_effect_confirmed -and
        [bool]$Receipt.baseline_behavior_passed -eq $BaselineBehaviorPassed -and
        [bool]$Receipt.push_behavior_passed -eq $PushBehaviorPassed -and
        [int]$Receipt.evaluation_world_build_count -eq 0 -and
        [int]$Receipt.model_construction_count -eq 0 -and
        [int]$Receipt.world_attempt_count -eq 0 -and
        [int]$Receipt.world_build_count -eq 0 -and
        [int]$Receipt.scene_tree_insertion_count -eq 0 -and
        [int]$Receipt.native_readback_count -eq 0 -and
        [int]$Receipt.solver_step_count -eq 0 -and
        -not [bool]$Receipt.physics_state_modified -and
        -not [bool]$Receipt.physical_acceptance_authority -and
        -not [bool]$Receipt.release_authority
    )
    if (-not $exact) {
        throw "Pair seed $ExpectedSeed did not exactly bind both retained native cells"
    }
}

function Get-CellId {
    param([string]$ArmId, [int]$Seed)
    $prefix = if ($ArmId -ceq "matched_no_impulse_control") {
        "baseline"
    } else { "push" }
    return "${prefix}_s${Seed}"
}

function Get-OrderedCellIds {
    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($seed in $campaign.seeds) {
        foreach ($arm in $armOrder) {
            $ids.Add((Get-CellId -ArmId $arm -Seed ([int]$seed)))
        }
    }
    return @($ids)
}

function Invoke-GodotCaptured {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkerRoot,
        [Parameter(Mandatory)][int]$TimeoutSeconds,
        [hashtable]$AdditionalEnvironment = @{}
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godotPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    foreach ($name in $AdditionalEnvironment.Keys) {
        $start.Environment[[string]$name] = [string]$AdditionalEnvironment[$name]
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    if (-not $process.Start()) { throw "Failed to start Godot" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        started_utc = $startedUtc.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
        stdout = $stdout
        stderr = $stderr
    }
}

function Get-SingleMarkerJson {
    param(
        [Parameter(Mandatory)][string]$Stdout,
        [Parameter(Mandatory)][string]$Marker
    )
    $lines = @(
        $Stdout -split "`r?`n" |
            Where-Object { $_.StartsWith($Marker, [StringComparison]::Ordinal) }
    )
    if ($lines.Count -ne 1) {
        throw "Expected one '$Marker' line; observed $($lines.Count)"
    }
    return (
        $lines[0].Substring($Marker.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
    )
}

function Assert-ZeroWorldReceipt {
    param([hashtable]$Receipt, [string]$Label)
    $exact = (
        [bool]$Receipt.ok -and
        [int]$Receipt.model_construction_count -eq 0 -and
        [int]$Receipt.world_attempt_count -eq 0 -and
        [int]$Receipt.world_build_count -eq 0 -and
        [int]$Receipt.scene_tree_insertion_count -eq 0 -and
        [int]$Receipt.native_readback_count -eq 0 -and
        [int]$Receipt.solver_step_count -eq 0 -and
        -not [bool]$Receipt.physics_state_modified -and
        -not [bool]$Receipt.physical_acceptance_authority
    )
    if (-not $exact) {
        throw "$Label did not remain an exact zero-world receipt"
    }
}

function Invoke-ZeroWorldMode {
    param([string]$TempRoot)
    $ordinalPathOrderControlPassed = (
        (Test-StrictOrdinalStringOrder -Values @(
            "sdk/Cargo.lock",
            "sdk/adapters/godot/Cargo.toml"
        )) -and
        -not (Test-StrictOrdinalStringOrder -Values @(
            "sdk/adapters/godot/Cargo.toml",
            "sdk/Cargo.lock"
        )) -and
        -not (Test-StrictOrdinalStringOrder -Values @(
            "sdk/Cargo.lock",
            "sdk/Cargo.lock"
        ))
    )
    if (-not $ordinalPathOrderControlPassed) {
        throw "R10D strict ordinal source-path ordering controls failed"
    }
    $source = Invoke-GodotCaptured -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $sourceTest
    ) -WorkerRoot (Join-Path $TempRoot "source") -TimeoutSeconds 120
    if ($source.exit_code -ne 0 -or $source.timed_out) {
        throw "R10D source gate failed: $($source.stderr)"
    }
    $sourceReceipt = Get-SingleMarkerJson -Stdout $source.stdout -Marker $sourceMarker
    Assert-ZeroWorldReceipt -Receipt $sourceReceipt -Label "source gate"

    $contract = Invoke-GodotCaptured -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $worker, "--", "contract"
    ) -WorkerRoot (Join-Path $TempRoot "contract") -TimeoutSeconds 120
    if ($contract.exit_code -ne 0 -or $contract.timed_out) {
        throw "R10D worker contract failed: $($contract.stderr)"
    }
    $contractReceipt = Get-SingleMarkerJson -Stdout $contract.stdout -Marker $contractMarker
    Assert-ZeroWorldReceipt -Receipt $contractReceipt -Label "worker contract"

    $preflightReceipts = [System.Collections.Generic.List[object]]::new()
    foreach ($role in @("development_route_ghost", "held_out_finite_decision")) {
        $preflight = Invoke-GodotCaptured -Arguments @(
            "--headless", "--path", $repoRoot, "--script", $worker,
            "--", "preflight", $role
        ) -WorkerRoot (Join-Path $TempRoot "preflight-$role") -TimeoutSeconds 120
        if ($preflight.exit_code -ne 0 -or $preflight.timed_out) {
            throw "R10D $role entrypoint preflight failed: $($preflight.stderr)"
        }
        $receipt = Get-SingleMarkerJson -Stdout $preflight.stdout -Marker $preflightMarker
        Assert-ZeroWorldReceipt -Receipt $receipt -Label "$role entrypoint preflight"
        $preflightReceipts.Add($receipt)
    }

    $bypass = Invoke-GodotCaptured -Arguments @(
        "--headless", "--path", $repoRoot, "--script", $worker,
        "--", "physical", "development_route_ghost",
        "matched_no_impulse_control", "40001"
    ) -WorkerRoot (Join-Path $TempRoot "blocked-bypass") -TimeoutSeconds 120
    if ($bypass.exit_code -eq 0 -or $bypass.timed_out) {
        throw "The direct physical worker bypass was not refused"
    }
    $bypassReceipt = Get-SingleMarkerJson -Stdout $bypass.stdout -Marker $cellMarker
    if (
        [bool]$bypassReceipt.ok -or
        [string]$bypassReceipt.failure_code -cne "QSDK_R10D_PHYSICAL_AUTHORIZATION_REQUIRED" -or
        [int]$bypassReceipt.model_construction_count -ne 0 -or
        [int]$bypassReceipt.world_attempt_count -ne 0 -or
        [int]$bypassReceipt.world_build_count -ne 0 -or
        [int]$bypassReceipt.solver_step_count -ne 0
    ) {
        throw "The direct physical bypass refusal was not exact"
    }
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r10d_supervisor_zero_world_v2"
        gate_id = "QSDK-R10D"
        repair_id = $repairId
        ok = $true
        failure_code = ""
        source_gate = $sourceReceipt
        worker_contract = $contractReceipt
        entrypoint_preflights = @($preflightReceipts)
        direct_physical_bypass_refused = $true
        ordinal_path_order_control_passed = $true
        ordinal_path_order_negative_control_count = 2
        physical_execution_authorized = $false
        locomotion_outcome_exposure_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        scene_tree_insertion_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
    }
    Write-Output (
        "QSDK_R10D_SUPERVISOR_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
}

function Get-RepositoryIdentity {
    $top = Get-GitText -Arguments @("rev-parse", "--show-toplevel") -Label "root"
    $remote = Get-GitText -Arguments @("remote", "get-url", "origin") -Label "remote"
    $branch = Get-GitText -Arguments @("branch", "--show-current") -Label "branch"
    $status = Get-GitText -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    ) -Label "status" -AllowEmpty
    $head = Get-GitText -Arguments @("rev-parse", "HEAD") -Label "HEAD"
    $parent = Get-GitText -Arguments @("rev-parse", "HEAD^") -Label "HEAD parent"
    $tree = Get-GitText -Arguments @("rev-parse", "HEAD^{tree}") -Label "HEAD tree"
    $origin = Get-GitText -Arguments @("rev-parse", "origin/main") -Label "origin/main"
    $liveLine = Get-GitText -Arguments @(
        "ls-remote", "origin", "refs/heads/main"
    ) -Label "live main"
    $liveParts = @($liveLine -split "\s+" | Where-Object { $_ })
    if ($liveParts.Count -ne 2 -or [string]$liveParts[1] -cne "refs/heads/main") {
        throw "Could not resolve live origin/main"
    }
    $live = [string]$liveParts[0]
    if (
        [System.IO.Path]::GetFullPath($top) -cne $repoRoot -or
        $remote -cne $expectedRemote -or
        $branch -cne "main" -or
        -not [string]::IsNullOrEmpty($status) -or
        -not (Test-LowerHex -Value $head -Length 40) -or
        -not (Test-LowerHex -Value $parent -Length 40) -or
        -not (Test-LowerHex -Value $tree -Length 40) -or
        $head -cne $origin -or
        $head -cne $live
    ) {
        throw "Physical source must be clean and equal to local, cached, and live main"
    }
    return [ordered]@{
        root = $repoRoot
        remote = $remote
        branch = $branch
        authorization_commit = $head
        authorization_parent_commit = $parent
        authorization_tree = $tree
        origin_main_commit = $origin
        live_main_commit = $live
        clean = $true
    }
}

function Get-QualifiedPhysicalAuthority {
    param([hashtable]$RepositoryIdentity)
    if (
        [string]::IsNullOrWhiteSpace($StageFreeze) -or
        [string]::IsNullOrWhiteSpace($ExecutionAuthority)
    ) {
        throw "Physical mode requires -StageFreeze and -ExecutionAuthority"
    }

    $freezePath = [System.IO.Path]::GetFullPath($StageFreeze)
    $authorityPath = [System.IO.Path]::GetFullPath($ExecutionAuthority)
    $expectedFreezePath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot $stageFreezeRelativePath)
    )
    $expectedAuthorityPath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot $executionAuthorityRelativePath)
    )
    if (
        $freezePath -cne $expectedFreezePath -or
        $authorityPath -cne $expectedAuthorityPath -or
        -not (Test-Path -LiteralPath $freezePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $authorityPath -PathType Leaf)
    ) {
        throw "The exact R10D stage freeze or execution authority is missing"
    }

    $freeze = Get-Content -LiteralPath $freezePath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $authority = Get-Content -LiteralPath $authorityPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $expectedCells = @(Get-OrderedCellIds)
    $sourceCommit = [string]$authority.source_commit
    $qualificationParentCommit = [string]$authority.qualification_parent_commit
    $qualificationCommit = [string]$authority.authorization_parent_commit
    $authorizationCommit = [string]$RepositoryIdentity.authorization_commit

    if (
        -not (Test-LowerHex -Value $sourceCommit -Length 40) -or
        -not (Test-LowerHex -Value $qualificationParentCommit -Length 40) -or
        -not (Test-LowerHex -Value $qualificationCommit -Length 40) -or
        $sourceCommit -cne $qualificationParentCommit -or
        [string]$RepositoryIdentity.authorization_parent_commit -cne $qualificationCommit
    ) {
        throw "The R10D commit graph identities are malformed"
    }

    $qualificationCommitParent = Get-GitText -Arguments @(
        "rev-parse", "$qualificationCommit^"
    ) -Label "qualification parent"
    $qualificationChangedPaths = @(
        (Get-GitText -Arguments @(
            "diff-tree", "--no-commit-id", "--name-only", "-r", $qualificationCommit
        ) -Label "qualification changed paths") -split [char]10
    )
    $authorizationChangedPaths = @(
        (Get-GitText -Arguments @(
            "diff-tree", "--no-commit-id", "--name-only", "-r", $authorizationCommit
        ) -Label "authorization changed paths") -split [char]10
    )
    $stageFreezeSpec = "{0}:{1}" -f $qualificationCommit, $stageFreezeRelativePath
    $currentFreezeSpec = "{0}:{1}" -f $authorizationCommit, $stageFreezeRelativePath
    $currentAuthoritySpec = "{0}:{1}" -f $authorizationCommit, $executionAuthorityRelativePath
    $stageFreezeBlob = Get-GitText -Arguments @(
        "rev-parse", $stageFreezeSpec
    ) -Label "committed stage freeze blob"
    $currentStageFreezeBlob = Get-GitText -Arguments @(
        "rev-parse", $currentFreezeSpec
    ) -Label "current stage freeze blob"
    $currentAuthorityBlob = Get-GitText -Arguments @(
        "rev-parse", $currentAuthoritySpec
    ) -Label "current execution authority blob"

    if (
        $qualificationCommitParent -cne $sourceCommit -or
        -not (Test-ExactStringArray -Actual $qualificationChangedPaths -Expected @($stageFreezeRelativePath)) -or
        -not (Test-ExactStringArray -Actual $authorizationChangedPaths -Expected @($executionAuthorityRelativePath)) -or
        $stageFreezeBlob -cne $currentStageFreezeBlob -or
        [string]$authority.stage_freeze_git_blob_oid -cne $stageFreezeBlob -or
        -not (Test-LowerHex -Value $currentAuthorityBlob -Length 40)
    ) {
        throw "R10D stage-freeze-only or authority-only commit ordering is invalid"
    }

    $sourceBindings = @($freeze.qualified_source_bindings)
    $bindingPaths = @($sourceBindings | ForEach-Object { [string]$_.path })
    if (
        $sourceBindings.Count -ne $qualifiedSourcePathCount -or
        -not (Test-StrictOrdinalStringOrder -Values $bindingPaths) -or
        (Get-TextSha256 -Text ($bindingPaths -join [char]10)) -cne $qualifiedSourcePathSha256
    ) {
        throw "R10D qualified source bindings do not match the frozen path set"
    }
    foreach ($binding in $sourceBindings) {
        $relative = [string]$binding.path
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $relative))
        if (
            -not $candidate.StartsWith(
                $repoRoot + [System.IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -or
            -not (Test-Path -LiteralPath $candidate -PathType Leaf)
        ) {
            throw "R10D qualified source binding escaped or is missing: $relative"
        }
        $sourceSpec = "{0}:{1}" -f $sourceCommit, $relative
        $currentSpec = "{0}:{1}" -f $authorizationCommit, $relative
        $sourceBlob = Get-GitText -Arguments @(
            "rev-parse", $sourceSpec
        ) -Label "source binding $relative"
        $currentBlob = Get-GitText -Arguments @(
            "rev-parse", $currentSpec
        ) -Label "current binding $relative"
        if (
            [string]$binding.git_blob_oid -cne $sourceBlob -or
            [string]$binding.git_blob_oid -cne $currentBlob -or
            [int64]$binding.byte_length -ne [int64](Get-Item -LiteralPath $candidate).Length -or
            [string]$binding.raw_sha256 -cne (Get-PrefixedSha256 $candidate)
        ) {
            throw "R10D qualified source binding drifted: $relative"
        }
    }

    $validateClosureBinding = {
        param(
            [hashtable]$Binding,
            [string]$RelativePath,
            [string]$ExpectedSha256,
            [int64]$ExpectedBytes
        )
        if ($Binding -isnot [System.Collections.IDictionary]) { return $false }
        $path = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $RelativePath))
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        $sourceSpec = "{0}:{1}" -f $sourceCommit, $RelativePath
        $currentSpec = "{0}:{1}" -f $authorizationCommit, $RelativePath
        $sourceBlob = Get-GitText -Arguments @(
            "rev-parse", $sourceSpec
        ) -Label "closure source binding $RelativePath"
        $currentBlob = Get-GitText -Arguments @(
            "rev-parse", $currentSpec
        ) -Label "closure current binding $RelativePath"
        return (
            [string]$Binding.path -ceq $RelativePath -and
            [int64]$Binding.byte_length -eq $ExpectedBytes -and
            [int64](Get-Item -LiteralPath $path).Length -eq $ExpectedBytes -and
            [string]$Binding.raw_sha256 -ceq $ExpectedSha256 -and
            (Get-PrefixedSha256 $path) -ceq $ExpectedSha256 -and
            [string]$Binding.git_blob_oid -ceq $sourceBlob -and
            [string]$Binding.git_blob_oid -ceq $currentBlob
        )
    }

    $predecessor = $freeze.consumed_r10b_held_out_closure
    $support = $freeze.r05e_supported_start_closure
    $l1Design = $freeze.r10d_l1_successor_design
    $consumedR10d = $freeze.consumed_r10d_development_route_closure
    $predecessorExact = (
        (& $validateClosureBinding $predecessor $r10bHeldOutClosureRelativePath $r10bHeldOutClosureSha256 30998) -and
        [string]$predecessor.status -ceq "closed_consumed_valid_complete_finite_negative" -and
        [bool]$predecessor.physical_identity_consumed -and
        -not [bool]$predecessor.same_identity_rerun_permitted -and
        -not [bool]$predecessor.bounded_upright_push_recovery_claimed
    )
    $supportExact = (
        (& $validateClosureBinding $support $r05ePhysicalClosureRelativePath $r05ePhysicalClosureSha256 49049) -and
        [string]$support.status -ceq "closed_consumed_complete_held_out_finite_positive_eligible_for_separate_qsdk_r05_adoption" -and
        [int]$support.selected_generator_index -eq 217 -and
        [string]$support.selected_morphology_id -ceq "qsdk_r05e_axis_star_torso_length_low_s217" -and
        (Test-ExactStringArray -Actual @(
            $support.supported_campaign_seeds | ForEach-Object { [string]$_ }
        ) -Expected @("40101", "40102", "40103")) -and
        [int]$support.walking_pass_count -eq 3 -and
        [int]$support.false_walking_receipt_count -eq 0 -and
        -not [bool]$support.external_push_recovery_claimed
    )
    $l1DesignExact = (
        (& $validateClosureBinding $l1Design $r10dL1DesignRelativePath $r10dL1DesignSha256 8548) -and
        [string]$l1Design.repair_id -ceq $repairId -and
        [bool]$l1Design.representation_only_repair -and
        -not [bool]$l1Design.new_physical_work_authorized_by_design
    )
    $consumedR10dExact = (
        (& $validateClosureBinding $consumedR10d $consumedR10dPhysicalClosureRelativePath $consumedR10dPhysicalClosureSha256 7196) -and
        [string]$consumedR10d.status -ceq "closed_consumed_invalid_or_incomplete_no_valid_route" -and
        -not [bool]$consumedR10d.route_execution_valid -and
        -not [bool]$consumedR10d.behavioral_conclusion_available -and
        [bool]$consumedR10d.physical_identity_consumed -and
        -not [bool]$consumedR10d.same_identity_rerun_permitted -and
        -not [bool]$consumedR10d.held_out_qualification_eligible
    )
    if (
        -not $predecessorExact -or
        -not $supportExact -or
        -not $l1DesignExact -or
        -not $consumedR10dExact
    ) {
        throw "R10D-L1 predecessor, design, or supported-start binding is invalid"
    }

    $qualificationEvidence = $freeze.qualification_evidence
    if ($qualificationEvidence -isnot [System.Collections.IDictionary]) {
        throw "R10D official qualification evidence binding is missing"
    }
    $qualificationEvidencePath = [System.IO.Path]::GetFullPath(
        [string]$qualificationEvidence.completion_path
    )
    if (
        -not $qualificationEvidencePath.StartsWith(
            $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Test-Path -LiteralPath $qualificationEvidencePath -PathType Leaf) -or
        [int64]$qualificationEvidence.completion_byte_length -ne [int64](Get-Item -LiteralPath $qualificationEvidencePath).Length -or
        [string]$qualificationEvidence.completion_raw_sha256 -cne (Get-PrefixedSha256 $qualificationEvidencePath)
    ) {
        throw "R10D official qualification evidence bytes drifted"
    }
    $qualificationCompletion = Get-Content -LiteralPath $qualificationEvidencePath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    if (
        [string]$qualificationCompletion.schema_version -cne "sporespore_qsdk_r10d_zero_world_qualification_completion_v2" -or
        [string]$qualificationCompletion.repair_id -cne $repairId -or
        [string]$qualificationCompletion.campaign_role -cne $CampaignRole -or
        [string]$qualificationCompletion.source.commit -cne $sourceCommit -or
        [string]$qualificationCompletion.r10d_l1_design_sha256 -cne $r10dL1DesignSha256 -or
        [string]$qualificationCompletion.consumed_r10d_physical_closure_sha256 -cne
            $consumedR10dPhysicalClosureSha256 -or
        -not [bool]$qualificationCompletion.qualification_passed -or
        [int]$qualificationCompletion.world_build_count -ne 0
    ) {
        throw "R10D official qualification completion is not exact"
    }
    $runtimeProjection = $qualificationCompletion.runtime_identity_projection
    if ($runtimeProjection -isnot [System.Collections.IDictionary]) {
        throw "R10D official qualification lacks its runtime identity projection"
    }
    $runtimeBinding = Assert-QualifiedRuntimeCurrent `
        -RuntimeProjection $runtimeProjection

    $authorityOutputRoot = [System.IO.Path]::GetFullPath([string]$authority.output_root)
    $outputInsideEvidenceRoot = $authorityOutputRoot.StartsWith(
        $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
    $claim = $freeze.claim_boundary
    $freezeExact = (
        [string]$freeze.schema_version -ceq $stageFreezeSchema -and
        [string]$freeze.status -ceq "closed_passing_official_zero_world_qualification" -and
        [string]$freeze.gate_id -ceq "QSDK-R10D" -and
        [string]$freeze.repair_id -ceq $repairId -and
        [string]$freeze.campaign_id -ceq [string]$campaign.id -and
        [string]$freeze.campaign_role -ceq $CampaignRole -and
        [string]$freeze.question_class -ceq [string]$campaign.question_class -and
        [string]$freeze.source_commit -ceq $sourceCommit -and
        [string]$freeze.qualification_parent_commit -ceq $sourceCommit -and
        [int]$freeze.qualified_source_path_count -eq $qualifiedSourcePathCount -and
        [string]$freeze.qualified_source_path_sha256 -ceq $qualifiedSourcePathSha256 -and
        [string]$freeze.r10c_design_sha256 -ceq $r10cDesignSha256 -and
        [string]$freeze.r10d_l1_design_sha256 -ceq $r10dL1DesignSha256 -and
        [string]$freeze.consumed_r10d_physical_closure_sha256 -ceq
            $consumedR10dPhysicalClosureSha256 -and
        [int]$freeze.maximum_world_count -eq [int]$campaign.maximum_world_count -and
        [bool]$freeze.official_zero_world_qualification_passed -and
        -not [bool]$freeze.physical_execution_authorized_by_freeze -and
        -not [bool]$freeze.physical_acceptance_authority -and
        -not [bool]$freeze.release_authority -and
        (Test-ExactStringArray -Actual @($freeze.ordered_cell_ids) -Expected $expectedCells) -and
        $claim -is [System.Collections.IDictionary] -and
        -not [bool]$claim.r10d_bounded_upright_push_recovery -and
        -not [bool]$claim.external_push_recovery -and
        -not [bool]$claim.fall_recovery -and
        -not [bool]$claim.force_aware_recovery -and
        -not [bool]$claim.release_authorized
    )
    if (-not $freezeExact) {
        throw "The R10D stage freeze is not exact"
    }

    $authorityExact = (
        [string]$authority.schema_version -ceq $authoritySchema -and
        [string]$authority.status -ceq "authorized_single_use_unconsumed" -and
        [string]$authority.gate_id -ceq "QSDK-R10D" -and
        [string]$authority.repair_id -ceq $repairId -and
        [string]$authority.campaign_id -ceq [string]$campaign.id -and
        [string]$authority.campaign_role -ceq $CampaignRole -and
        [string]$authority.question_class -ceq [string]$campaign.question_class -and
        [string]$authority.source_commit -ceq $sourceCommit -and
        [bool]$authority.authorization_commit_derived_from_current_head -and
        [string]$authority.authorization_parent_commit -ceq $qualificationCommit -and
        [string]$authority.qualification_parent_commit -ceq $sourceCommit -and
        [string]$authority.qualification_closure_path -ceq $stageFreezeRelativePath -and
        [string]$authority.r10c_design_sha256 -ceq $r10cDesignSha256 -and
        [string]$authority.r10d_l1_design_sha256 -ceq $r10dL1DesignSha256 -and
        [string]$authority.consumed_r10d_physical_closure_sha256 -ceq
            $consumedR10dPhysicalClosureSha256 -and
        [string]$authority.stage_freeze_sha256 -ceq (Get-PrefixedSha256 $freezePath) -and
        [string]$authority.consumed_r10b_held_out_closure_sha256 -ceq $r10bHeldOutClosureSha256 -and
        [string]$authority.r05e_physical_closure_sha256 -ceq $r05ePhysicalClosureSha256 -and
        [int]$authority.qualified_source_path_count -eq $qualifiedSourcePathCount -and
        [string]$authority.qualified_source_path_sha256 -ceq $qualifiedSourcePathSha256 -and
        -not [bool]$authority.physical_identity_consumed -and
        -not [bool]$authority.same_identity_rerun_permitted -and
        [bool]$authority.zero_world_qualification_passed -and
        [bool]$authority.physical_execution_authorized -and
        [int]$authority.maximum_world_count -eq [int]$campaign.maximum_world_count -and
        [int]$authority.maximum_campaign_attempt_count -eq 1 -and
        (Test-ExactStringArray -Actual @($authority.ordered_cell_ids) -Expected $expectedCells) -and
        $authorityOutputRoot -cne $evidenceRoot -and
        $outputInsideEvidenceRoot -and
        -not (Test-Path -LiteralPath $authorityOutputRoot) -and
        -not [bool]$authority.physical_acceptance_authority -and
        -not [bool]$authority.release_authority
    )
    if (-not $authorityExact) {
        throw "The R10D execution authority is not exact and unconsumed"
    }

    if ($CampaignRole -ceq "development_route_ghost") {
        if ($null -ne $freeze.prerequisite_development_route_ghost) {
            throw "The development freeze unexpectedly declares a route prerequisite"
        }
    } else {
        $prerequisite = $freeze.prerequisite_development_route_ghost
        if (
            $prerequisite -isnot [System.Collections.IDictionary] -or
            [string]$prerequisite.path -cne "sdk/qsdk_r10d_l1_development_route_ghost_physical_closure_v1.json" -or
            -not [bool]$prerequisite.route_execution_valid -or
            -not [bool]$prerequisite.physical_identity_consumed -or
            [bool]$prerequisite.same_identity_rerun_permitted
        ) {
            throw "The held-out freeze lacks the consumed valid development route"
        }
        $prerequisitePath = Join-Path $repoRoot ([string]$prerequisite.path)
        $prerequisiteSpec = "{0}:{1}" -f $sourceCommit, [string]$prerequisite.path
        $prerequisiteBlob = Get-GitText -Arguments @(
            "rev-parse", $prerequisiteSpec
        ) -Label "development route prerequisite blob"
        if (
            -not (Test-Path -LiteralPath $prerequisitePath -PathType Leaf) -or
            [string]$prerequisite.git_blob_oid -cne $prerequisiteBlob -or
            [string]$prerequisite.raw_sha256 -cne (Get-PrefixedSha256 $prerequisitePath)
        ) {
            throw "The held-out development route prerequisite bytes do not match"
        }
    }

    return [ordered]@{
        repair_id = $repairId
        source_commit = $sourceCommit
        qualification_parent_commit = $sourceCommit
        qualification_commit = $qualificationCommit
        authorization_commit = $authorizationCommit
        stage_freeze_path = $freezePath
        stage_freeze_sha256 = Get-PrefixedSha256 $freezePath
        execution_authority_path = $authorityPath
        execution_authority_sha256 = Get-PrefixedSha256 $authorityPath
        output_root = $authorityOutputRoot
        runtime_identity_projection = $runtimeProjection
        runtime_identity_sha256 = [string]$runtimeBinding.runtime_identity_sha256
        godot_raw_sha256 = [string]$runtimeBinding.godot_raw_sha256
        godot_byte_length = [int64]$runtimeBinding.godot_byte_length
        active_adapter_raw_sha256 = [string]$runtimeBinding.active_adapter_raw_sha256
        active_adapter_byte_length = [int64]$runtimeBinding.active_adapter_byte_length
        document = $authority
    }
}

function Invoke-AuthorityCheckMode {
    $identity = Get-RepositoryIdentity
    $qualifiedAuthority = Get-QualifiedPhysicalAuthority -RepositoryIdentity $identity
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r10d_authority_check_zero_world_v2"
        gate_id = "QSDK-R10D"
        repair_id = $repairId
        campaign_id = [string]$campaign.id
        campaign_role = $CampaignRole
        question_class = [string]$campaign.question_class
        ok = $true
        failure_code = ""
        source_commit = [string]$qualifiedAuthority.source_commit
        qualification_parent_commit = [string]$qualifiedAuthority.qualification_parent_commit
        qualification_commit = [string]$qualifiedAuthority.qualification_commit
        authorization_commit = [string]$qualifiedAuthority.authorization_commit
        stage_freeze_sha256 = [string]$qualifiedAuthority.stage_freeze_sha256
        execution_authority_sha256 = [string]$qualifiedAuthority.execution_authority_sha256
        runtime_identity_sha256 = [string]$qualifiedAuthority.runtime_identity_sha256
        godot_raw_sha256 = [string]$qualifiedAuthority.godot_raw_sha256
        godot_byte_length = [int64]$qualifiedAuthority.godot_byte_length
        active_adapter_raw_sha256 = [string]$qualifiedAuthority.active_adapter_raw_sha256
        active_adapter_byte_length = [int64]$qualifiedAuthority.active_adapter_byte_length
        output_root = [string]$qualifiedAuthority.output_root
        output_root_absent = -not (Test-Path -LiteralPath ([string]$qualifiedAuthority.output_root))
        physical_execution_authorized_for_later_separate_invocation = $true
        physical_execution_started = $false
        locomotion_outcome_exposure_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        scene_tree_insertion_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output (
        "QSDK_R10D_AUTHORITY_CHECK_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
}

function Invoke-PhysicalMode {
    param([string]$TempRoot)
    $operationLock = Enter-SporeSporeLocomotionOperationLock `
        -Role ([string]$campaign.operation_role) -TimeoutMilliseconds 0
    if (-not [bool]$operationLock.acquired) {
        throw "Another physical locomotion operation owns the serial lock"
    }
    try {
        $identity = Get-RepositoryIdentity
        $qualifiedAuthority = Get-QualifiedPhysicalAuthority -RepositoryIdentity $identity
        $operationLockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt `
            -Receipt $operationLock
        $outputPath = [string]$qualifiedAuthority.output_root
        if (
            -not [string]::IsNullOrWhiteSpace($Output) -and
            [System.IO.Path]::GetFullPath($Output) -cne $outputPath
        ) {
            throw "-Output must exactly match the execution authority output_root"
        }
        if (-not $outputPath.StartsWith(
            $evidenceRoot + [System.IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Physical output must be inside the durable SporeSpore_Evidence root"
        }
        if (Test-Path -LiteralPath $outputPath) {
            throw "Refusing to overwrite an existing physical evidence directory"
        }
        [void][System.IO.Directory]::CreateDirectory($outputPath)
        $cellRecords = [System.Collections.Generic.List[object]]::new()
        $pairRecords = [System.Collections.Generic.List[object]]::new()
        $worldAttemptCount = 0
        $campaignFailure = $null
        $failureStage = "campaign_initialization"
        $activeSeed = $null
        $activeArm = ""
        $activeCellId = ""
        try {
            foreach ($seedValue in $campaign.seeds) {
                $seed = [int]$seedValue
                $activeSeed = $seed
                $cellPaths = [ordered]@{}
                $cellReceipts = [ordered]@{}
                foreach ($arm in $armOrder) {
                $activeArm = $arm
                $cellId = Get-CellId -ArmId $arm -Seed $seed
                $activeCellId = $cellId
                $failureStage = "physical_cell_runtime_precheck"
                [void](Assert-QualifiedRuntimeCurrent `
                    -RuntimeProjection $qualifiedAuthority.runtime_identity_projection)
                $failureStage = "physical_cell_attempt_materialization"
                $cellRoot = Join-Path $outputPath $cellId
                [void][System.IO.Directory]::CreateDirectory($cellRoot)
                $attemptToken = [Guid]::NewGuid().ToString("N")
                $attemptPath = Join-Path $cellRoot "attempt.json"
                $attempt = [ordered]@{
                    schema_version = $attemptSchema
                    authorization_token = $attemptToken
                    campaign_id = [string]$campaign.id
                    gate_id = "QSDK-R10D"
                    repair_id = $repairId
                    campaign_role = $CampaignRole
                    arm_id = $arm
                    campaign_seed = $seed
                    cell_id = $cellId
                    source_commit = [string]$qualifiedAuthority.source_commit
                    authorization_commit = [string]$qualifiedAuthority.authorization_commit
                    authorization_parent_commit = [string]$qualifiedAuthority.qualification_commit
                    qualification_parent_commit = [string]$qualifiedAuthority.qualification_parent_commit
                    r10c_design_sha256 = $r10cDesignSha256
                    r10d_l1_design_sha256 = $r10dL1DesignSha256
                    consumed_r10d_physical_closure_sha256 = $consumedR10dPhysicalClosureSha256
                    consumed_r10b_held_out_closure_sha256 = $r10bHeldOutClosureSha256
                    r05e_physical_closure_sha256 = $r05ePhysicalClosureSha256
                    stage_freeze_path = [string]$qualifiedAuthority.stage_freeze_path
                    stage_freeze_sha256 = [string]$qualifiedAuthority.stage_freeze_sha256
                    execution_authority_path = [string]$qualifiedAuthority.execution_authority_path
                    execution_authority_sha256 = [string]$qualifiedAuthority.execution_authority_sha256
                    runtime_identity_sha256 = [string]$qualifiedAuthority.runtime_identity_sha256
                    godot_raw_sha256 = [string]$qualifiedAuthority.godot_raw_sha256
                    godot_byte_length = [int64]$qualifiedAuthority.godot_byte_length
                    active_adapter_raw_sha256 = [string]$qualifiedAuthority.active_adapter_raw_sha256
                    active_adapter_byte_length = [int64]$qualifiedAuthority.active_adapter_byte_length
                    output_root = $outputPath
                    synthetic_authorization_preflight = $false
                    supervisor_physical_authorized = $true
                    maximum_world_attempt_count = 1
                    maximum_world_build_count = 1
                    world_attempt_count_before_worker = 0
                    world_build_count_before_worker = 0
                    same_identity_rerun_permitted = $false
                    operation_lock = $operationLockPublic
                    physical_acceptance_authority = $false
                }
                Write-Utf8NoBom -Path $attemptPath -Text (
                    $attempt | ConvertTo-Json -Depth 50 -Compress
                )
                $worldAttemptCount++
                $failureStage = "physical_cell_process"
                $execution = Invoke-GodotCaptured -Arguments @(
                    "--headless", "--path", $repoRoot,
                    "--log-file", (Join-Path $cellRoot "godot.log"),
                    "--script", $worker, "--", "physical",
                    $CampaignRole, $arm, ([string]$seed)
                ) -WorkerRoot (Join-Path $cellRoot "runtime") `
                    -TimeoutSeconds $CellTimeoutSeconds -AdditionalEnvironment @{
                        SPORESPORE_QSDK_R10D_ATTEMPT = $attemptPath
                        SPORESPORE_QSDK_R10D_TOKEN = $attemptToken
                    }
                Write-Utf8NoBom -Path (Join-Path $cellRoot "stdout.log") `
                    -Text ([string]$execution.stdout)
                Write-Utf8NoBom -Path (Join-Path $cellRoot "stderr.log") `
                    -Text ([string]$execution.stderr)
                $failureStage = "physical_cell_runtime_revalidation"
                [void](Assert-QualifiedRuntimeCurrent `
                    -RuntimeProjection $qualifiedAuthority.runtime_identity_projection)
                if ($execution.timed_out -or $execution.exit_code -ne 0) {
                    throw "Physical cell $cellId failed or timed out; identity is consumed"
                }
                $failureStage = "physical_cell_receipt_validation"
                $cellReceipt = Get-SingleMarkerJson `
                    -Stdout ([string]$execution.stdout) -Marker $cellMarker
                Assert-PhysicalCellReceipt -Receipt $cellReceipt `
                    -ExpectedArmId $arm -ExpectedSeed $seed `
                    -ExpectedCellId $cellId -QualifiedAuthority $qualifiedAuthority `
                    -AttemptPath $attemptPath
                $cellPath = Join-Path $cellRoot "cell.json"
                Write-Utf8NoBom -Path $cellPath -Text (
                    $cellReceipt | ConvertTo-Json -Depth 100 -Compress
                )
                $cellSha256 = Get-PrefixedSha256 $cellPath
                $cellPaths[$arm] = $cellPath
                $cellReceipts[$arm] = $cellReceipt
                $cellRecords.Add([ordered]@{
                    cell_id = $cellId
                    arm_id = $arm
                    campaign_seed = $seed
                    path = $cellPath
                    raw_sha256 = $cellSha256
                    behavior_passed = [bool]$cellReceipt.behavior_passed
                    evidence_valid = [bool]$cellReceipt.evidence_valid
                })
            }
            $activeArm = ""
            $activeCellId = ""
            $failureStage = "pair_runtime_revalidation"
            [void](Assert-QualifiedRuntimeCurrent `
                -RuntimeProjection $qualifiedAuthority.runtime_identity_projection)
            $failureStage = "pair_evaluation_process"
            $pairExecution = Invoke-GodotCaptured -Arguments @(
                "--headless", "--path", $repoRoot, "--script", $worker,
                "--", "pair-evaluate",
                ([string]$cellPaths["matched_no_impulse_control"]),
                ([string]$cellPaths["lateral_upright_impulse"])
            ) -WorkerRoot (Join-Path $outputPath "pair-s$seed-runtime") `
                -TimeoutSeconds 120
            [void](Assert-QualifiedRuntimeCurrent `
                -RuntimeProjection $qualifiedAuthority.runtime_identity_projection)
            if ($pairExecution.timed_out -or $pairExecution.exit_code -ne 0) {
                throw "Pair evaluation for seed $seed was invalid"
            }
            $failureStage = "pair_receipt_validation"
            $pairReceipt = Get-SingleMarkerJson `
                -Stdout ([string]$pairExecution.stdout) -Marker $pairMarker
            $baselineCellSha256 = Get-PrefixedSha256 `
                ([string]$cellPaths["matched_no_impulse_control"])
            $pushCellSha256 = Get-PrefixedSha256 `
                ([string]$cellPaths["lateral_upright_impulse"])
            Assert-PairReceipt -Receipt $pairReceipt -ExpectedSeed $seed `
                -BaselineCellSha256 $baselineCellSha256 `
                -PushCellSha256 $pushCellSha256 `
                -BaselineBehaviorPassed ([bool]$cellReceipts["matched_no_impulse_control"].behavior_passed) `
                -PushBehaviorPassed ([bool]$cellReceipts["lateral_upright_impulse"].behavior_passed)
            $pairPath = Join-Path $outputPath "pair-s$seed.json"
            Write-Utf8NoBom -Path $pairPath -Text (
                $pairReceipt | ConvertTo-Json -Depth 100 -Compress
            )
            $pairRecords.Add([ordered]@{
                campaign_seed = $seed
                path = $pairPath
                raw_sha256 = Get-PrefixedSha256 $pairPath
                behavior_passed = [bool]$pairReceipt.behavior_passed
                native_effect_confirmed = [bool]$pairReceipt.native_effect_confirmed
            })
        }
        } catch {
            $campaignFailure = $_
        }
        $complete = (
            $null -eq $campaignFailure -and
            $worldAttemptCount -eq [int]$campaign.maximum_world_count -and
            $cellRecords.Count -eq [int]$campaign.maximum_world_count -and
            $pairRecords.Count -eq @($campaign.seeds).Count
        )
        $behaviorPassed = $complete
        foreach ($record in $pairRecords) {
            $behaviorPassed = $behaviorPassed -and [bool]$record.behavior_passed
        }
        $report = [ordered]@{
            schema_version = "sporespore_qsdk_r10d_physical_report_v2"
            gate_id = "QSDK-R10D"
            repair_id = $repairId
            campaign_id = [string]$campaign.id
            campaign_role = $CampaignRole
            question_class = [string]$campaign.question_class
            status = if ($behaviorPassed) {
                "complete_valid_positive"
            } elseif ($complete) {
                "complete_valid_finite_negative"
            } else { "invalid_or_incomplete" }
            source = [ordered]@{
                source_freeze_commit = [string]$qualifiedAuthority.source_commit
                qualification_parent_commit = [string]$qualifiedAuthority.qualification_parent_commit
                qualification_commit = [string]$qualifiedAuthority.qualification_commit
                authorization_commit = [string]$qualifiedAuthority.authorization_commit
                authorization_tree = [string]$identity.authorization_tree
                branch = [string]$identity.branch
                remote = [string]$identity.remote
                origin_main_commit = [string]$identity.origin_main_commit
                live_main_commit = [string]$identity.live_main_commit
                clean = [bool]$identity.clean
            }
            stage_freeze_sha256 = [string]$qualifiedAuthority.stage_freeze_sha256
            execution_authority_sha256 = [string]$qualifiedAuthority.execution_authority_sha256
            runtime_identity_sha256 = [string]$qualifiedAuthority.runtime_identity_sha256
            godot_raw_sha256 = [string]$qualifiedAuthority.godot_raw_sha256
            godot_byte_length = [int64]$qualifiedAuthority.godot_byte_length
            active_adapter_raw_sha256 = [string]$qualifiedAuthority.active_adapter_raw_sha256
            active_adapter_byte_length = [int64]$qualifiedAuthority.active_adapter_byte_length
            r10c_design_sha256 = $r10cDesignSha256
            r10d_l1_design_sha256 = $r10dL1DesignSha256
            consumed_r10d_physical_closure_sha256 = $consumedR10dPhysicalClosureSha256
            consumed_r10b_held_out_closure_sha256 = $r10bHeldOutClosureSha256
            r05e_physical_closure_sha256 = $r05ePhysicalClosureSha256
            output_root = $outputPath
            ordered_cell_ids = @(Get-OrderedCellIds)
            world_attempt_count = $worldAttemptCount
            world_build_count = if ($complete) { $cellRecords.Count } else { $null }
            world_build_count_known = $complete
            confirmed_valid_world_build_count = $cellRecords.Count
            expected_world_count = [int]$campaign.maximum_world_count
            pair_count = $pairRecords.Count
            complete = $complete
            evidence_valid = $complete
            outcome_complete = $complete
            behavioral_conclusion_available = $complete
            behavior_passed = if ($complete) { $behaviorPassed } else { $null }
            cells = @($cellRecords)
            pairs = @($pairRecords)
            failure_record = if ($null -eq $campaignFailure) {
                $null
            } else {
                [ordered]@{
                    schema_version = "sporespore_qsdk_r10d_physical_failure_v2"
                    repair_id = $repairId
                    failure_code = "QSDK_R10D_PHYSICAL_CAMPAIGN_INVALID_OR_INCOMPLETE"
                    failure_stage = $failureStage
                    campaign_seed = $activeSeed
                    arm_id = $activeArm
                    cell_id = $activeCellId
                    message = [string]$campaignFailure.Exception.Message
                    behavioral_conclusion_available = $false
                    same_identity_rerun_permitted = $false
                }
            }
            same_identity_rerun_permitted = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        $reportPath = Join-Path $outputPath "report.json"
        Write-Utf8NoBom -Path $reportPath -Text (
            $report | ConvertTo-Json -Depth 100
        )
        Write-Output (
            "QSDK_R10D_PHYSICAL_COMPLETE " +
            ([ordered]@{
                report_path = $reportPath
                report_sha256 = Get-PrefixedSha256 $reportPath
                output_root = $outputPath
                repair_id = $repairId
                status = [string]$report.status
                world_attempt_count = $worldAttemptCount
                world_build_count = $report.world_build_count
                world_build_count_known = [bool]$report.world_build_count_known
                confirmed_valid_world_build_count = $cellRecords.Count
                behavior_passed = $report.behavior_passed
                same_identity_rerun_permitted = $false
            } | ConvertTo-Json -Compress)
        )
        if ($null -ne $campaignFailure) {
            throw (
                "Physical campaign is invalid or incomplete; identity is consumed and " +
                "the terminal report is retained at $reportPath"
            )
        }
    } finally {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase (
    "sporespore-qsdk-r10d-" + [Guid]::NewGuid().ToString("N")
)
[void][System.IO.Directory]::CreateDirectory($tempRoot)
try {
    if ($Mode -ceq "ZeroWorld") {
        Invoke-ZeroWorldMode -TempRoot $tempRoot
    } elseif ($Mode -ceq "AuthorityCheck") {
        Invoke-AuthorityCheckMode
    } else {
        Invoke-PhysicalMode -TempRoot $tempRoot
    }
} finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
    if (
        (Test-Path -LiteralPath $resolvedTemp) -and
        $resolvedTemp.StartsWith(
            $tempBase,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        $resolvedTemp.Length -gt ($tempBase.Length + 24)
    ) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
