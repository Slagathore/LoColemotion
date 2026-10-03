#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$incidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc3_incident.json"
)
$casRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256"

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-Lca1Rc3Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC3_INCIDENT $Message" }
}

function Read-Lca1Rc3IncidentJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc3IncidentSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc3Incident([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-Lca1Rc3IncidentCas(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Record,
    [Parameter(Mandatory)][string]$LocalPath,
    [Parameter(Mandatory)][string]$Label
) {
    $digest = ([string]$Record.sha256).Substring(7)
    $directory = Join-Path $casRoot $digest
    Assert-Lca1Rc3Incident (
        (Test-Path -LiteralPath $LocalPath -PathType Leaf) -and
        (Get-Lca1Rc3IncidentSha256 $LocalPath) -ceq
            [string]$Record.sha256 -and
        (Get-Item -LiteralPath $LocalPath).Length -eq
            [long]$Record.byte_length -and
        (Test-SporeSporeStoredArtifact `
            -Directory $directory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$Record.byte_length))
    ) "retained CAS object changed: $Label"
}

function Test-Lca1Rc3IncidentDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
        "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -or
        [string]$Document.incident_id -cne "LCA1-RC3-COLD-PAIR-20260815" -or
        [string]$Document.status -cne
            "closed_invalid_complete_process_pair_frozen_claim_vector_contradiction") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question -or
        [string]$Document.observed_source_identity.commit -cne
            "3cdc4a8cafecf40051c5f6dea1b186fccb991cc8" -or
        [string]$Document.observed_source_identity.tree_git_oid -cne
            "9cc200b7eb77568fb4583c35c55a1b590608d0ac" -or
        -not [bool]$Document.observed_source_identity.worktree_clean) {
        $failures.Add("SOURCE_QUESTION")
    }
    if (-not [bool]$Document.preregistration.
            frozen_all_full_and_scoped_claims_must_remain_false -or
        [bool]$Document.preregistration.
            same_source_rerun_after_complete_or_failed_pair_allowed -or
        (@($Document.launch.execution_order) -join "|") -cne
            "complete_full_godot_v2|scoped_lca1_rc3" -or
        -not [bool]$Document.launch.serialized -or
        -not [bool]$Document.launch.full_attempted -or
        -not [bool]$Document.launch.scoped_attempted -or
        [bool]$Document.launch.same_source_rerun_authorized) {
        $failures.Add("LAUNCH_FREEZE")
    }
    $full = $Document.cold_full_v2
    if ([string]$full.status -cne "passed" -or
        [double]$full.duration_seconds -ne 1175.455846 -or
        [int]$full.required_stage_count -ne 8 -or
        [int]$full.stage_receipt_count -ne 8 -or
        [int]$full.failed_stage_count -ne 0 -or
        [string]$full.cache_status -cne "disabled_uncommissioned" -or
        [bool]$full.cache_lookup_performed -or
        [bool]$full.result_reused -or
        [bool]$full.transitive_dependency_key_complete -or
        -not [bool]$full.all_claim_values_false -or
        [bool]$full.one_shot_physical_campaign_executed -or
        [int]$full.physical_worlds_opened -ne 0) {
        $failures.Add("FULL")
    }
    $scoped = $Document.cold_scoped_lca1
    if ([string]$scoped.status -cne
            "campaign_local_godot_including_qualification_passed" -or
        [double]$scoped.duration_seconds -ne 77.8065461 -or
        [int]$scoped.global_gate_count -ne 12 -or
        [int]$scoped.lineage_gate_count -ne 1 -or
        [int]$scoped.campaign_role_gate_count -ne 3 -or
        [int]$scoped.executed_gate_count -ne 16 -or
        [int]$scoped.failed_gate_count -ne 0 -or
        [int]$scoped.gate_cas_reference_count -ne 48 -or
        [int]$scoped.unique_gate_cas_payload_count -ne 35 -or
        -not [bool]$scoped.all_gate_streams_content_addressed -or
        (@($scoped.observed_true_claim_keys) -join "|") -cne
            "campaign_local_qualification_passed" -or
        [bool]$scoped.all_claim_values_false -or
        -not [bool]$scoped.
            all_authority_scientific_and_release_claim_values_false -or
        [int]$scoped.physical_process_launch_count -ne 0 -or
        [int]$scoped.physical_worlds_opened -ne 0 -or
        [bool]$scoped.commissioned) {
        $failures.Add("SCOPED")
    }
    $comparison = $Document.pair_comparison
    foreach ($name in @(
        "same_source_commit_and_tree",
        "same_godot_identity",
        "same_powershell_identity",
        "same_python_identity",
        "same_cargo_identity",
        "same_rustc_identity",
        "same_host_os_and_process_architecture",
        "duration_ratio_descriptive_only"
    )) {
        if (-not [bool]$comparison[$name]) { $failures.Add("PAIR_IDENTITY") }
    }
    if ([bool]$comparison.duration_ratio_acceptance_role -or
        [double]$comparison.numeric_equivalence_margin -ne 0.0 -or
        [int]$comparison.marker_cardinality_margin -ne 0 -or
        [int]$comparison.source_runtime_host_identity_margin -ne 0) {
        $failures.Add("MARGINS")
    }
    $exact = $Document.exact_acceptance_comparison
    if (-not [bool]$exact.frozen_requirement_value -or
        -not [bool]$exact.full_all_claim_values_false -or
        [bool]$exact.scoped_all_claim_values_false -or
        [string]$exact.scoped_only_true_claim_key -cne
            "campaign_local_qualification_passed" -or
        -not [bool]$exact.scoped_schema_requires_local_qualification_true_on_success -or
        -not [bool]$exact.all_other_full_and_scoped_acceptance_conditions_satisfied -or
        [bool]$exact.literal_frozen_claim_vector_condition_satisfied -or
        [bool]$exact.complete_exact_acceptance_satisfied) {
        $failures.Add("EXACT_ACCEPTANCE")
    }
    $interpretation = $Document.interpretation
    if (-not [bool]$interpretation.process_execution_completed -or
        -not [bool]$interpretation.full_process_passed -or
        -not [bool]$interpretation.scoped_process_passed -or
        [bool]$interpretation.executor_equivalence_or_non_inferiority_promoted -or
        [bool]$interpretation.commissioning_passed -or
        [bool]$interpretation.process_input_failure -or
        [bool]$interpretation.physics_failure -or
        [bool]$interpretation.scientific_failure -or
        [string]$interpretation.failure_class -cne
            "frozen_claim_vector_incompatible_with_successful_scoped_attestation" -or
        [bool]$interpretation.same_source_rerun_authorized -or
        [bool]$interpretation.observed_threshold_or_interpretation_rewrite_authorized -or
        [bool]$interpretation.controller_change_authorized -or
        [bool]$interpretation.physics_change_authorized -or
        [bool]$interpretation.physical_rerun_authorized_by_incident) {
        $failures.Add("INTERPRETATION")
    }
    $claims = $Document.claims
    $trueClaims = @($claims.Keys | Where-Object { [bool]$claims[$_] })
    if ((@($trueClaims | Sort-Object) -join "|") -cne
        "rc3_full_half_passed|rc3_pair_completed|rc3_scoped_half_passed" -or
        [bool]$claims.rc3_exact_acceptance_satisfied -or
        [bool]$claims.rc3_commissioning_passed -or
        [bool]$claims.current_executor_commissioned -or
        [bool]$claims.physical_launch_prerequisite_satisfied -or
        [bool]$claims.physical_campaign_executed -or
        [bool]$claims.scientific_result -or
        [bool]$claims.walking_acceptance -or
        [bool]$claims.turning_acceptance -or
        [bool]$claims.cross_engine_equivalence -or
        [bool]$claims.release_authority -or
        [bool]$claims.physical_acceptance_authority) {
        $failures.Add("CLAIMS")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

Assert-Lca1Rc3Incident (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$incident = Read-Lca1Rc3IncidentJson $incidentPath
$documentTest = Test-Lca1Rc3IncidentDocument -Document $incident
Assert-Lca1Rc3Incident ([bool]$documentTest.ok) (
    "incident document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "closed_positive" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "source"; apply = { param($d) $d.observed_source_identity.commit = "0" * 40 } },
    @{ name = "rerun"; apply = { param($d) $d.preregistration.same_source_rerun_after_complete_or_failed_pair_allowed = $true } },
    @{ name = "full_stage_count"; apply = { param($d) $d.cold_full_v2.stage_receipt_count = 7 } },
    @{ name = "scoped_gate_count"; apply = { param($d) $d.cold_scoped_lca1.executed_gate_count = 15 } },
    @{ name = "cas_count"; apply = { param($d) $d.cold_scoped_lca1.gate_cas_reference_count = 47 } },
    @{ name = "claim_vector"; apply = { param($d) $d.cold_scoped_lca1.all_claim_values_false = $true } },
    @{ name = "literal_acceptance"; apply = { param($d) $d.exact_acceptance_comparison.literal_frozen_claim_vector_condition_satisfied = $true } },
    @{ name = "commissioning"; apply = { param($d) $d.interpretation.commissioning_passed = $true } },
    @{ name = "duration_role"; apply = { param($d) $d.pair_comparison.duration_ratio_acceptance_role = $true } },
    @{ name = "marker_margin"; apply = { param($d) $d.pair_comparison.marker_cardinality_margin = 1 } },
    @{ name = "physics_failure"; apply = { param($d) $d.interpretation.physics_failure = $true } },
    @{ name = "authority"; apply = { param($d) $d.claims.physical_acceptance_authority = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $copy = Copy-Lca1Rc3Incident $incident
    & $mutation.apply $copy
    $result = Test-Lca1Rc3IncidentDocument -Document $copy
    Assert-Lca1Rc3Incident (-not [bool]$result.ok) (
        "incident mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals++
}

foreach ($role in @("freeze", "manifest", "freeze_audit")) {
    $pathKey = $role + "_path"
    $hashKey = $role + "_raw_sha256"
    $bytesKey = $role + "_byte_length"
    $absolute = Join-Path $repoRoot ([string]$incident.preregistration[$pathKey])
    Assert-Lca1Rc3Incident (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-Lca1Rc3IncidentSha256 $absolute) -ceq
            [string]$incident.preregistration[$hashKey] -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$incident.preregistration[$bytesKey]
    ) "RC3 preregistration binding changed: $role"
}

$fullAttestationPath = [string]$incident.cold_full_v2.full_attestation.path
$fullReceiptPath = [string]$incident.cold_full_v2.run_receipt.path
$fullLogPath = [string]$incident.cold_full_v2.full_log.path
foreach ($record in @(
    $incident.cold_full_v2.full_attestation,
    $incident.cold_full_v2.run_receipt,
    $incident.cold_full_v2.full_log,
    $incident.cold_scoped_lca1.attestation
)) {
    Assert-Lca1Rc3Incident (
        (Test-Path -LiteralPath ([string]$record.path) -PathType Leaf) -and
        (Get-Lca1Rc3IncidentSha256 ([string]$record.path)) -ceq
            [string]$record.raw_sha256 -and
        (Get-Item -LiteralPath ([string]$record.path)).Length -eq
            [long]$record.byte_length
    ) "retained primary evidence changed: $($record.path)"
    if ([bool]$record.cas_required) {
        Test-Lca1Rc3IncidentCas -Record ([ordered]@{
            sha256 = [string]$record.raw_sha256
            byte_length = [long]$record.byte_length
        }) -LocalPath ([string]$record.path) -Label ([string]$record.path)
    }
}

$fullAttestation = Read-Lca1Rc3IncidentJson $fullAttestationPath
$fullReceipt = Read-Lca1Rc3IncidentJson $fullReceiptPath
Assert-Lca1Rc3Incident (
    [string]$fullAttestation.status -ceq "full_godot_conformance_passed" -and
    [bool]$fullAttestation.conformance.passed -and
    -not [bool]$fullAttestation.conformance.one_shot_physical_campaign_executed -and
    [string]$fullAttestation.source.commit -ceq
        [string]$incident.observed_source_identity.commit -and
    [string]$fullAttestation.source.tree_git_oid -ceq
        [string]$incident.observed_source_identity.tree_git_oid -and
    @($fullAttestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    [string]$fullReceipt.status -ceq "passed" -and
    [string]$fullReceipt.tier -ceq "full_cold" -and
    -not [bool]$fullReceipt.skip_godot -and
    [string]$fullReceipt.source.head -ceq
        [string]$incident.observed_source_identity.commit -and
    [string]$fullReceipt.source.head_tree -ceq
        [string]$incident.observed_source_identity.tree_git_oid -and
    @($fullReceipt.stage_receipts).Count -eq 8 -and
    @($fullReceipt.stage_receipts | Where-Object {
        [string]$_.status -cne "passed" -or [int]$_.exit_code -ne 0
    }).Count -eq 0 -and
    [string]$fullReceipt.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$fullReceipt.cache.lookup_performed -and
    -not [bool]$fullReceipt.cache.result_reused -and
    @($fullReceipt.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "retained full-half semantics changed"

$fullStageCasCount = 0
foreach ($stage in @($fullReceipt.stage_receipts)) {
    Test-Lca1Rc3IncidentCas -Record ([ordered]@{
        sha256 = [string]$stage.receipt_raw_sha256
        byte_length = (Get-Item -LiteralPath ([string]$stage.receipt_path)).Length
    }) -LocalPath ([string]$stage.receipt_path) -Label ([string]$stage.stage_id)
    $fullStageCasCount++
}
Test-Lca1Rc3IncidentCas -Record ([ordered]@{
    sha256 = [string]$fullReceipt.full_log.raw_sha256
    byte_length = [long]$fullReceipt.full_log.byte_length
}) -LocalPath ([string]$fullReceipt.full_log.path) -Label "full_log"

$fullText = [IO.File]::ReadAllText($fullLogPath)
foreach ($marker in @($incident.cold_full_v2.required_terminal_marker_counts.Keys)) {
    $count = [regex]::Matches(
        $fullText,
        [regex]::Escape([string]$marker)
    ).Count
    Assert-Lca1Rc3Incident (
        $count -eq
            [int]$incident.cold_full_v2.required_terminal_marker_counts[$marker]
    ) "full marker cardinality changed: $marker"
}

$scoped = Read-Lca1Rc3IncidentJson (
    [string]$incident.cold_scoped_lca1.attestation.path
)
$trueScopedClaims = @(
    $scoped.claims.Keys | Where-Object { [bool]$scoped.claims[$_] }
)
Assert-Lca1Rc3Incident (
    [string]$scoped.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$scoped.source.commit -ceq
        [string]$incident.observed_source_identity.commit -and
    [string]$scoped.source.tree_git_oid -ceq
        [string]$incident.observed_source_identity.tree_git_oid -and
    [int]$scoped.declared_physical_world_count -eq 0 -and
    [int]$scoped.global_gate_count -eq 12 -and
    [int]$scoped.lineage_gate_count -eq 1 -and
    [int]$scoped.campaign_gate_count -eq 3 -and
    [int]$scoped.executed_gate_count -eq 16 -and
    [bool]$scoped.all_gates_executed -and
    [bool]$scoped.all_gate_streams_content_addressed -and
    -not [bool]$scoped.commissioned -and
    (@($trueScopedClaims) -join "|") -ceq
        "campaign_local_qualification_passed" -and
    @($scoped.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.exit_code -ne 0 -or
        [bool]$_.timed_out -or [int]$_.physical_process_launch_count -ne 0 -or
        [int]$_.physical_world_count -ne 0 -or
        [bool]$_.physical_acceptance_authority
    }).Count -eq 0
) "retained scoped-half semantics changed"

$scopedCasCount = 0
$uniqueScopedCas = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($gate in @($scoped.gate_receipts)) {
    foreach ($role in @("stdout", "stderr", "receipt")) {
        $cas = $gate[$role + "_cas"]
        $path = [string]$gate[$role + "_path"]
        Test-Lca1Rc3IncidentCas -Record $cas -LocalPath $path -Label (
            [string]$gate.gate_id + "_" + $role
        )
        [void]$uniqueScopedCas.Add([string]$cas.sha256)
        $scopedCasCount++
    }
}
Assert-Lca1Rc3Incident (
    $scopedCasCount -eq 48 -and $uniqueScopedCas.Count -eq 35
) "scoped CAS counts changed"
foreach ($marker in @($incident.cold_scoped_lca1.required_terminal_marker_counts.Keys)) {
    $matches = @($scoped.gate_receipts | Where-Object {
        [string]$_.terminal_marker -clike ([string]$marker + " *") -and
        [int]$_.terminal_marker_count -eq 1
    })
    Assert-Lca1Rc3Incident (
        $matches.Count -eq
            [int]$incident.cold_scoped_lca1.required_terminal_marker_counts[$marker]
    ) "scoped marker cardinality changed: $marker"
}

$runtime = $incident.pair_comparison
Assert-Lca1Rc3Incident (
    [string]$fullReceipt.toolchain_runtime_identity.powershell.executable_sha256 -ceq
        [string]$runtime.powershell.executable_raw_sha256 -and
    [string]$scoped.runtime.powershell.executable_sha256 -ceq
        [string]$runtime.powershell.executable_raw_sha256 -and
    [string]$fullReceipt.toolchain_runtime_identity.godot.executable_sha256 -ceq
        [string]$runtime.godot.executable_raw_sha256 -and
    [string]$scoped.runtime.godot.executable_sha256 -ceq
        [string]$runtime.godot.executable_raw_sha256 -and
    [string]$fullReceipt.toolchain_runtime_identity.python.executable_sha256 -ceq
        [string]$runtime.python.executable_raw_sha256 -and
    [string]$scoped.runtime.python.executable_sha256 -ceq
        [string]$runtime.python.executable_raw_sha256 -and
    [string]$fullReceipt.toolchain_runtime_identity.cargo.executable_sha256 -ceq
        [string]$runtime.cargo.executable_raw_sha256 -and
    [string]$scoped.runtime.cargo.executable_sha256 -ceq
        [string]$runtime.cargo.executable_raw_sha256 -and
    [string]$fullReceipt.toolchain_runtime_identity.rustc.executable_sha256 -ceq
        [string]$runtime.rustc.executable_raw_sha256 -and
    [string]$scoped.runtime.rustc.executable_sha256 -ceq
        [string]$runtime.rustc.executable_raw_sha256 -and
    [string]$fullReceipt.toolchain_runtime_identity.operating_system -ceq
        [string]$runtime.host_os_description -and
    [string]$scoped.runtime.host.os_description -ceq
        [string]$runtime.host_os_description -and
    [string]$scoped.runtime.host.process_architecture -ceq
        [string]$runtime.host_process_architecture
) "retained pair runtime identity changed"

Write-Host (
    "LCA1_RC3_INCIDENT_PASS class=equivalence_non_inferiority " +
    "full_stages=$fullStageCasCount scoped_gates=16 scoped_cas=$scopedCasCount " +
    "unique_scoped_cas=$($uniqueScopedCas.Count) exact_acceptance=False " +
    "true_scoped_claim=campaign_local_qualification_passed " +
    "mutations=$mutationRefusals models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)
