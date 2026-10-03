#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$incidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc2_incident.json"
)

. (Join-Path $sdkRoot "conformance_dependency_key.ps1")
. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-Lca1Rc2Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC2_INCIDENT $Message" }
}

function Read-Lca1Rc2IncidentJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc2IncidentSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc2Incident([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-Lca1Rc2IncidentDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
        "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -or
        [string]$Document.incident_id -cne "LCA1-RC2-COLD-PAIR-20260815" -or
        [string]$Document.status -cne
            "closed_negative_full_stage_1_runtime_profile_mismatch_scoped_not_started") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("QUESTION")
    }
    if ([string]$Document.observed_source_identity.commit -cne
            "0d5c44986a4783269fead70b14472fcdbace7736" -or
        [string]$Document.observed_source_identity.tree_git_oid -cne
            "6f3ff1f469f1c31a709d3e5bb64eb89152644a0b" -or
        -not [bool]$Document.observed_source_identity.worktree_clean) {
        $failures.Add("SOURCE")
    }
    if ([bool]$Document.preregistration.
            same_source_rerun_after_complete_or_failed_pair_allowed -or
        [bool]$Document.launch.full_attestation_created -or
        [bool]$Document.launch.scoped_output_root_created -or
        [bool]$Document.launch.scoped_attempted) {
        $failures.Add("LAUNCH")
    }
    $full = $Document.cold_full_v2
    if ([string]$full.status -cne "failed_stage_1_runtime_profile_mismatch" -or
        [double]$full.duration_seconds -ne 38.8401454 -or
        [int]$full.stage_receipt_count -ne 1 -or
        [int]$full.failed_stage_count -ne 1 -or
        [string]$full.first_failed_stage_id -cne
            "authority_and_historical_closures" -or
        [int]$full.first_failed_stage_ordinal -ne 1 -or
        [int]$full.first_failed_stage_exit_code -ne 1 -or
        [string]$full.failure_message -cne
            "PowerShell runtime profile file count or byte count changed." -or
        [string]$full.cache_status -cne "disabled_uncommissioned" -or
        [bool]$full.result_reused -or
        [int]$full.physical_process_launch_count -ne 0 -or
        [int]$full.model_construction_count -ne 0 -or
        [int]$full.world_attempt_count -ne 0 -or
        [int]$full.world_build_count -ne 0) {
        $failures.Add("FULL")
    }
    $scoped = $Document.cold_scoped_lca1
    if ([string]$scoped.status -cne
            "not_started_after_full_stage_1_failure" -or
        [bool]$scoped.attempted -or
        [bool]$scoped.output_root_created -or
        [int]$scoped.gate_execution_count -ne 0 -or
        [int]$scoped.gate_cas_object_count -ne 0 -or
        [int]$scoped.physical_worlds_opened -ne 0) {
        $failures.Add("SCOPED")
    }
    $runtime = $Document.runtime_profile_comparison
    if ([string]$runtime.profile_id -cne
            "windows-powershell-git-r23d13-parent-child-v2" -or
        [int]$runtime.declared_relative_file_count -ne 86 -or
        [int]$runtime.expected_file_count -ne 86 -or
        [long]$runtime.expected_byte_count -ne 85258167 -or
        [string]$runtime.matching_runtime.version -cne "7.6.4" -or
        [long]$runtime.matching_runtime.observed_byte_count -ne 85258167 -or
        -not [bool]$runtime.matching_runtime.profile_shape_match -or
        [string]$runtime.attempted_runtime.version -cne "7.6.0-preview.6" -or
        [long]$runtime.attempted_runtime.observed_byte_count -ne 85403280 -or
        [int]$runtime.attempted_runtime.file_count_delta -ne 0 -or
        [long]$runtime.attempted_runtime.byte_count_delta -ne 145113 -or
        [bool]$runtime.attempted_runtime.profile_shape_match) {
        $failures.Add("RUNTIME")
    }
    $interpretation = $Document.interpretation
    if ([bool]$interpretation.physics_failure -or
        [bool]$interpretation.scientific_failure -or
        [bool]$interpretation.executor_semantics_evaluated -or
        -not [bool]$interpretation.process_commissioning_failure -or
        [string]$interpretation.failure_class -cne
            "launch_runtime_did_not_match_live_declared_runtime_profile" -or
        [bool]$interpretation.same_source_rerun_authorized -or
        [bool]$interpretation.threshold_change_authorized -or
        [bool]$interpretation.controller_change_authorized -or
        [bool]$interpretation.physics_change_authorized -or
        [bool]$interpretation.physical_rerun_authorized_by_incident) {
        $failures.Add("INTERPRETATION")
    }
    $claims = $Document.claims
    if (-not [bool]$claims.rc2_full_half_attempted -or
        [bool]$claims.rc2_pair_completed -or
        [bool]$claims.rc2_commissioning_passed -or
        [bool]$claims.current_executor_commissioned -or
        [bool]$claims.physical_launch_prerequisite_satisfied -or
        [bool]$claims.physical_campaign_executed -or
        [bool]$claims.scientific_result -or
        [bool]$claims.walking_acceptance -or
        [bool]$claims.turning_acceptance -or
        [bool]$claims.cross_engine_equivalence -or
        [bool]$claims.release_authority -or
        [bool]$claims.physical_acceptance_authority -or
        @($claims.Values | Where-Object { [bool]$_ }).Count -ne 1) {
        $failures.Add("CLAIMS")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

Assert-Lca1Rc2Incident (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$incident = Read-Lca1Rc2IncidentJson $incidentPath
$documentTest = Test-Lca1Rc2IncidentDocument -Document $incident
Assert-Lca1Rc2Incident ([bool]$documentTest.ok) (
    "incident document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "passed" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "source"; apply = { param($d) $d.observed_source_identity.commit = "0" * 40 } },
    @{ name = "rerun"; apply = { param($d) $d.preregistration.same_source_rerun_after_complete_or_failed_pair_allowed = $true } },
    @{ name = "full_status"; apply = { param($d) $d.cold_full_v2.status = "passed" } },
    @{ name = "stage_count"; apply = { param($d) $d.cold_full_v2.stage_receipt_count = 8 } },
    @{ name = "scoped_attempt"; apply = { param($d) $d.cold_scoped_lca1.attempted = $true } },
    @{ name = "expected_bytes"; apply = { param($d) $d.runtime_profile_comparison.expected_byte_count++ } },
    @{ name = "attempted_bytes"; apply = { param($d) $d.runtime_profile_comparison.attempted_runtime.observed_byte_count-- } },
    @{ name = "byte_delta"; apply = { param($d) $d.runtime_profile_comparison.attempted_runtime.byte_count_delta = 0 } },
    @{ name = "physics_failure"; apply = { param($d) $d.interpretation.physics_failure = $true } },
    @{ name = "authority"; apply = { param($d) $d.claims.physical_acceptance_authority = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $copy = Copy-Lca1Rc2Incident $incident
    & $mutation.apply $copy
    $result = Test-Lca1Rc2IncidentDocument -Document $copy
    Assert-Lca1Rc2Incident (-not [bool]$result.ok) (
        "incident mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals++
}

foreach ($bindingName in @("freeze", "manifest", "freeze_audit")) {
    $pathKey = $bindingName + "_path"
    $hashKey = $bindingName + "_raw_sha256"
    $bytesKey = $bindingName + "_byte_length"
    $absolute = Join-Path $repoRoot ([string]$incident.preregistration[$pathKey])
    Assert-Lca1Rc2Incident (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-Lca1Rc2IncidentSha256 $absolute) -ceq
            [string]$incident.preregistration[$hashKey] -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$incident.preregistration[$bytesKey]
    ) "RC2 preregistration binding changed: $bindingName"
}

$evidenceRecords = @(
    $incident.cold_full_v2.run_receipt,
    $incident.cold_full_v2.full_log,
    $incident.cold_full_v2.failure_excerpt,
    $incident.cold_full_v2.failed_stage_receipt
)
$casVerifiedCount = 0
foreach ($record in $evidenceRecords) {
    $path = [string]$record.path
    $digest = ([string]$record.raw_sha256).Substring(7)
    $casDirectory = Join-Path (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256"
    ) $digest
    Assert-Lca1Rc2Incident (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Lca1Rc2IncidentSha256 $path) -ceq [string]$record.raw_sha256 -and
        (Get-Item -LiteralPath $path).Length -eq [long]$record.byte_length -and
        [bool]$record.cas_required -and [bool]$record.cas_verified -and
        (Test-SporeSporeStoredArtifact `
            -Directory $casDirectory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$record.byte_length))
    ) "retained RC2 artifact or CAS changed: $path"
    $casVerifiedCount++
}

$receipt = Read-Lca1Rc2IncidentJson ([string]$incident.cold_full_v2.run_receipt.path)
$stage = Read-Lca1Rc2IncidentJson ([string]$incident.cold_full_v2.failed_stage_receipt.path)
Assert-Lca1Rc2Incident (
    [string]$receipt.schema_version -ceq
        "sporespore_conformance_run_observation_v1" -and
    [string]$receipt.run_id -ceq [string]$incident.cold_full_v2.run_id -and
    [string]$receipt.status -ceq "failed" -and
    [string]$receipt.tier -ceq "full_cold" -and
    -not [bool]$receipt.skip_godot -and
    [string]$receipt.source.head -ceq
        [string]$incident.observed_source_identity.commit -and
    [string]$receipt.source.head_tree -ceq
        [string]$incident.observed_source_identity.tree_git_oid -and
    [string]$receipt.source.origin_main -ceq
        [string]$incident.observed_source_identity.origin_main -and
    [bool]$receipt.source.worktree_clean -and
    @($receipt.stage_receipts).Count -eq 1 -and
    [string]$receipt.stage_receipts[0].stage_id -ceq
        "authority_and_historical_closures" -and
    [string]$receipt.stage_receipts[0].status -ceq "failed" -and
    [string]$receipt.failure.message -ceq
        [string]$incident.cold_full_v2.failure_message -and
    [string]$receipt.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$receipt.cache.lookup_performed -and
    -not [bool]$receipt.cache.result_reused -and
    @($receipt.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "retained RC2 run receipt semantics changed"
Assert-Lca1Rc2Incident (
    [string]$receipt.toolchain_runtime_identity.powershell.executable_sha256 -ceq
        [string]$incident.runtime_profile_comparison.attempted_runtime.executable_raw_sha256 -and
    [string]$receipt.toolchain_runtime_identity.powershell.version -ceq
        [string]$incident.runtime_profile_comparison.attempted_runtime.version -and
    [string]$receipt.toolchain_runtime_identity.godot.executable_sha256 -ceq
        [string]$incident.runtime_profile_comparison.godot_executable_raw_sha256 -and
    [string]$receipt.toolchain_runtime_identity.godot.version -ceq
        [string]$incident.runtime_profile_comparison.godot_version
) "retained RC2 runtime receipt changed"
Assert-Lca1Rc2Incident (
    [string]$stage.status -ceq "failed" -and
    [int]$stage.ordinal -eq 1 -and
    [int]$stage.exit_code -eq 1 -and
    [string]$stage.error.message -ceq
        [string]$incident.cold_full_v2.failure_message -and
    [string]$stage.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$stage.cache.result_reused -and
    @($stage.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "retained RC2 failed stage semantics changed"

$pairRoot = [string]$incident.launch.pair_root
Assert-Lca1Rc2Incident (
    (Test-Path -LiteralPath $pairRoot -PathType Container) -and
    @(Get-ChildItem -LiteralPath $pairRoot -Force).Count -eq 0 -and
    -not (Test-Path -LiteralPath ([string]$incident.launch.full_attestation_path)) -and
    -not (Test-Path -LiteralPath ([string]$incident.launch.scoped_output_root))
) "RC2 create-only pair-root boundary changed"

$runtime = $incident.runtime_profile_comparison
foreach ($role in @("profile_contract", "profile_registry", "profile_evaluator")) {
    $absolute = Join-Path $repoRoot ([string]$runtime[$role + "_path"])
    Assert-Lca1Rc2Incident (
        (Get-Lca1Rc2IncidentSha256 $absolute) -ceq
            [string]$runtime[$role + "_raw_sha256"] -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$runtime[$role + "_byte_length"]
    ) "runtime-profile source changed: $role"
}
$registry = Get-SporeSporeConformanceRuntimeProfileRegistry
$profile = @($registry.profiles)[0]
$stableInventory = Get-SporeSporeDeclaredFileInventory `
    -Root "C:\Program Files\PowerShell\7" `
    -RelativePaths @($profile.powershell.relative_files) `
    -InventoryId "powershell_r23d13_parent"
$previewInventory = Get-SporeSporeDeclaredFileInventory `
    -Root "C:\Program Files\PowerShell\7-preview" `
    -RelativePaths @($profile.powershell.relative_files) `
    -InventoryId "powershell_rc2_failed_preview_runtime"
Assert-Lca1Rc2Incident (
    [string]$profile.profile_id -ceq [string]$runtime.profile_id -and
    @($profile.powershell.relative_files).Count -eq
        [int]$runtime.declared_relative_file_count -and
    [int]$profile.powershell.observed_file_count -eq
        [int]$runtime.expected_file_count -and
    [long]$profile.powershell.observed_byte_count -eq
        [long]$runtime.expected_byte_count -and
    [int]$stableInventory.file_count -eq
        [int]$runtime.matching_runtime.observed_file_count -and
    [long]$stableInventory.byte_count -eq
        [long]$runtime.matching_runtime.observed_byte_count -and
    [string]$stableInventory.inventory_sha256 -ceq
        [string]$runtime.matching_runtime.inventory_sha256 -and
    [int]$previewInventory.file_count -eq
        [int]$runtime.attempted_runtime.observed_file_count -and
    [long]$previewInventory.byte_count -eq
        [long]$runtime.attempted_runtime.observed_byte_count -and
    [string]$previewInventory.inventory_sha256 -ceq
        [string]$runtime.attempted_runtime.inventory_sha256
) "runtime-profile measured inventories changed"

foreach ($runtimeRole in @("matching_runtime", "attempted_runtime")) {
    $record = $runtime[$runtimeRole]
    $path = [string]$record.executable_path
    $identity = & $path -NoLogo -NoProfile -Command (
        '$PSVersionTable.PSVersion.ToString() + "|" + ' +
        '$PSVersionTable.PSEdition + "|" + ' +
        '[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription'
    )
    $expectedIdentity = (
        [string]$record.version + "|" + [string]$record.edition + "|" +
        [string]$record.framework_description
    )
    Assert-Lca1Rc2Incident (
        (Get-Lca1Rc2IncidentSha256 $path) -ceq
            [string]$record.executable_raw_sha256 -and
        $identity -ceq $expectedIdentity
    ) "PowerShell executable identity changed: $runtimeRole"
}

Write-Host (
    "LCA1_RC2_INCIDENT_PASS class=equivalence_non_inferiority " +
    "full_stage_receipts=1 scoped_gates=0 cas=$casVerifiedCount " +
    "runtime_file_delta=0 runtime_byte_delta=145113 mutations=$mutationRefusals " +
    "models=0 worlds=0 physical_authority=False release_authority=False"
)
