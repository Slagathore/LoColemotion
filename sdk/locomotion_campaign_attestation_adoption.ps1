#requires -Version 7.0

Set-StrictMode -Version Latest

$script:SporeSporeCampaignAdoptionSchema =
    "sporespore_locomotion_campaign_attestation_adoption_v1"
$script:SporeSporeCampaignAdoptionContractPath = Join-Path `
    $PSScriptRoot "locomotion_campaign_attestation_adoption_contract_v1.json"
$script:SporeSporeCampaignAdoptionClaimNames = @(
    "commissioned_executor_verified",
    "campaign_local_qualification_passed",
    "physical_launch_prerequisite_satisfied",
    "physical_campaign_executed",
    "scientific_result",
    "walking_acceptance",
    "turning_acceptance",
    "cross_engine_equivalence",
    "release_authority",
    "physical_acceptance_authority"
)

. (Join-Path $PSScriptRoot "locomotion_campaign_attestation.ps1")

function Get-SporeSporeCampaignAdoptionContract {
    [CmdletBinding()]
    param([string]$Path = $script:SporeSporeCampaignAdoptionContractPath)
    $contract = Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
    if ([string]$contract.schema_version -cne
            "sporespore_locomotion_campaign_attestation_adoption_contract_v1" -or
        [string]$contract.status -cne
            "commissioned_executor_campaign_composition_enabled" -or
        @($contract.commissioned_core_source_bindings).Count -ne 10 -or
        [int]$contract.candidate_requirements.global_gate_count -ne 12 -or
        [int]$contract.candidate_requirements.required_campaign_role_gate_count -ne 3 -or
        (@($contract.candidate_requirements.required_roles) -join "|") -cne
            "worker|evaluator|supervisor" -or
        -not [bool]$contract.claims.commissioned_executor_verified -or
        -not [bool]$contract.claims.campaign_local_qualification_required -or
        -not [bool]$contract.claims.physical_launch_prerequisite_may_be_satisfied) {
        throw "Campaign-attestation adoption contract is malformed."
    }
    foreach ($name in @(
        "physical_campaign_executed", "scientific_result", "walking_acceptance",
        "turning_acceptance", "cross_engine_equivalence", "release_authority",
        "physical_acceptance_authority"
    )) {
        if ([bool]$contract.claims[$name]) {
            throw "Campaign-attestation adoption contract overclaims $name."
        }
    }
    return $contract
}

function Test-SporeSporeCampaignAdoptionDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Document,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne $script:SporeSporeCampaignAdoptionSchema) {
        $failures.Add("SCHEMA")
    }
    if ([string]$Document.status -cne
        "commissioned_campaign_local_qualification_adopted_for_physical_launch") {
        $failures.Add("STATUS")
    }
    foreach ($field in @(
        "campaign_id", "source_commit", "source_tree_git_oid",
        "manifest_raw_sha256", "scoped_attestation_raw_sha256",
        "commissioning_closure_raw_sha256", "commissioning_audit_raw_sha256",
        "runtime_inventory_sha256", "candidate_inventory_sha256"
    )) {
        if ([string]$Document[$field] -cne [string]$Expected[$field]) {
            $failures.Add("IDENTITY::$field")
        }
    }
    foreach ($field in @(
        "declared_physical_world_count", "global_gate_count", "lineage_gate_count",
        "campaign_gate_count", "executed_gate_count", "gate_cas_object_count"
    )) {
        if ([int]$Document[$field] -ne [int]$Expected[$field]) {
            $failures.Add("COUNT::$field")
        }
    }
    if ((@($Document.role_bindings) | ConvertTo-Json -Depth 50 -Compress) -cne
        (@($Expected.role_bindings) | ConvertTo-Json -Depth 50 -Compress)) {
        $failures.Add("ROLE_BINDINGS")
    }
    if (-not [bool]$Document.commissioned_executor_verified -or
        -not [bool]$Document.campaign_local_attestation_verified -or
        -not [bool]$Document.all_gate_cas_objects_verified -or
        -not [bool]$Document.scoped_attestation_cas_verified -or
        -not [bool]$Document.clean_pushed_live_source_verified -or
        -not [bool]$Document.runtime_matches_commissioning -or
        -not [bool]$Document.physical_launch_prerequisite_satisfied -or
        [bool]$Document.physical_acceptance_authority -or
        [bool]$Document.release_authority) {
        $failures.Add("BOUNDARY")
    }
    $actualClaimNames = @($Document.claims.Keys | Sort-Object)
    $expectedClaimNames = @($script:SporeSporeCampaignAdoptionClaimNames | Sort-Object)
    if (($actualClaimNames | ConvertTo-Json -Compress) -cne
        ($expectedClaimNames | ConvertTo-Json -Compress)) {
        $failures.Add("CLAIM_SCHEMA")
    }
    foreach ($name in $script:SporeSporeCampaignAdoptionClaimNames) {
        $expectedValue = $name -cin @(
            "commissioned_executor_verified",
            "campaign_local_qualification_passed",
            "physical_launch_prerequisite_satisfied"
        )
        if (-not $Document.claims.Contains($name) -or
            [bool]$Document.claims[$name] -ne $expectedValue) {
            $failures.Add("CLAIM::$name")
        }
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
        physical_launch_prerequisite_satisfied = $failures.Count -eq 0
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Get-SporeSporeCampaignAdoptionVerifiedInputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ScopedAttestationPath,
        [Parameter(Mandatory)][string]$Godot,
        [string]$Python = "python",
        [Parameter(Mandatory)][string]$ExpectedCampaignId
    )
    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $contract = Get-SporeSporeCampaignAdoptionContract
    $closurePath = Join-Path $repo ([string]$contract.commissioning_closure.path)
    $auditPath = Join-Path $repo ([string]$contract.commissioning_closure.audit_path)
    foreach ($pair in @(
        @($closurePath, [string]$contract.commissioning_closure.raw_sha256),
        @($auditPath, [string]$contract.commissioning_closure.audit_raw_sha256)
    )) {
        if (-not (Test-Path -LiteralPath $pair[0] -PathType Leaf) -or
            (Get-SporeSporeCampaignAttestationSha256 $pair[0]) -cne $pair[1]) {
            throw "Commissioning closure or audit bytes changed: $($pair[0])"
        }
    }
    $auditOutput = @(& $auditPath *>&1)
    $auditSucceeded = $?
    foreach ($line in $auditOutput) { Write-Host ([string]$line) }
    if (-not $auditSucceeded -or @($auditOutput | Where-Object {
        ([string]$_).StartsWith(
            [string]$contract.commissioning_closure.required_terminal_marker_prefix,
            [StringComparison]::Ordinal
        )
    }).Count -ne 1) {
        throw "Commissioning closure audit failed."
    }
    $closure = Get-Content -Raw -LiteralPath $closurePath |
        ConvertFrom-Json -AsHashtable -Depth 100
    if (-not [bool]$closure.comparison.commissioning_passed -or
        -not [bool]$closure.adoption_boundary.separate_fail_closed_adoption_composition_required -or
        -not [bool]$closure.claims.campaign_local_attestation_implementation_commissioned -or
        [string]$closure.commissioned_implementation_source.commit -cne
            [string]$contract.commissioning_closure.commissioned_source_commit -or
        [string]$closure.commissioned_implementation_source.tree_git_oid -cne
            [string]$contract.commissioning_closure.commissioned_source_tree) {
        throw "Commissioning closure does not authorize adoption composition."
    }

    $source = Get-SporeSporeAttestationSourceIdentity `
        -RepoRoot $repo -RequireCleanPushedLive
    $candidate = Get-SporeSporeCampaignAttestationCandidate `
        -RepoRoot $repo -ManifestPath $ManifestPath
    $runtime = Get-SporeSporeCampaignAttestationRuntimeIdentity `
        -Godot $Godot -Python $Python
    if ([string]$candidate.manifest.status -cne
            [string]$contract.candidate_requirements.status -or
        [string]$candidate.campaign_id -cne $ExpectedCampaignId -or
        [int]$candidate.global_gate_count -ne 12 -or
        [int]$candidate.lineage_gate_count -lt 1 -or
        [int]$candidate.campaign_gate_count -ne 3 -or
        -not [bool]$candidate.godot_including) {
        throw "Campaign-local candidate scope changed."
    }
    $commissionedBindings = @($contract.commissioned_core_source_bindings)
    for ($index = 0; $index -lt $commissionedBindings.Count; $index++) {
        $expectedBinding = $commissionedBindings[$index]
        $actualBinding = @($candidate.core_source_bindings | Where-Object {
            [string]$_.path -ceq [string]$expectedBinding.path
        })
        if ($actualBinding.Count -ne 1 -or
            [string]$actualBinding[0].raw_sha256 -cne
                [string]$expectedBinding.raw_sha256) {
            throw "Commissioned executor source changed: $($expectedBinding.path)"
        }
    }

    $baselinePath = [string]$closure.scoped_lca1.attestation.path
    if ((Get-SporeSporeCampaignAttestationSha256 $baselinePath) -cne
        [string]$closure.scoped_lca1.attestation.raw_sha256) {
        throw "Commissioning baseline attestation changed."
    }
    $baseline = Get-Content -Raw -LiteralPath $baselinePath |
        ConvertFrom-Json -AsHashtable -Depth 100
    if (($runtime | ConvertTo-Json -Depth 100 -Compress) -cne
        ($baseline.runtime | ConvertTo-Json -Depth 100 -Compress)) {
        throw "Runtime or host changed since LCA1 commissioning."
    }

    $attestationResolved = [IO.Path]::GetFullPath($ScopedAttestationPath)
    $attestation = Get-Content -Raw -LiteralPath $attestationResolved |
        ConvertFrom-Json -AsHashtable -Depth 100
    $attestationTest = Test-SporeSporeCampaignAttestationDocument `
        -Document $attestation -Candidate $candidate `
        -ExpectedSource $source -ExpectedRuntime $runtime
    if (-not [bool]$attestationTest.ok) {
        throw "Scoped campaign attestation failed: $(@($attestationTest.failure_codes) -join ',')"
    }
    $attestationSha = Get-SporeSporeCampaignAttestationSha256 $attestationResolved
    $attestationBytes = (Get-Item -LiteralPath $attestationResolved).Length
    $artifactRoot = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repo
    ) "artifacts\sha256"
    $attestationDigest = $attestationSha.Substring(7)
    if (-not (Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $attestationDigest) `
        -ExpectedSha256 $attestationDigest `
        -ExpectedByteLength $attestationBytes)) {
        throw "Scoped campaign attestation CAS object is missing or changed."
    }
    $gateCasCount = 0
    foreach ($gate in @($attestation.gate_receipts)) {
        foreach ($field in @("stdout_cas", "stderr_cas", "receipt_cas")) {
            $cas = $gate[$field]
            $digest = ([string]$cas.sha256).Substring(7)
            if (-not (Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent ([string]$cas.payload_path)) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$cas.byte_length))) {
                throw "Campaign gate CAS changed: $($gate.gate_id)/$field"
            }
            $gateCasCount++
        }
    }
    $roles = @($attestation.campaign_role_bindings)
    if ((@($roles.role) -join "|") -cne "worker|evaluator|supervisor") {
        throw "Campaign role bindings changed."
    }
    $sourceAfter = Get-SporeSporeAttestationSourceIdentity `
        -RepoRoot $repo -RequireCleanPushedLive
    if ([string]$sourceAfter.commit -cne [string]$source.commit -or
        [string]$sourceAfter.tree_git_oid -cne [string]$source.tree_git_oid) {
        throw "Source changed during campaign-attestation adoption verification."
    }
    $expected = [ordered]@{
        campaign_id = $ExpectedCampaignId
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        manifest_raw_sha256 = Get-SporeSporeCampaignAttestationSha256 $ManifestPath
        scoped_attestation_raw_sha256 = $attestationSha
        commissioning_closure_raw_sha256 =
            [string]$contract.commissioning_closure.raw_sha256
        commissioning_audit_raw_sha256 =
            [string]$contract.commissioning_closure.audit_raw_sha256
        runtime_inventory_sha256 =
            Get-SporeSporeCampaignAttestationObjectSha256 $runtime
        candidate_inventory_sha256 = [string]$candidate.inventory_sha256
        declared_physical_world_count = [int]$candidate.declared_physical_world_count
        global_gate_count = [int]$candidate.global_gate_count
        lineage_gate_count = [int]$candidate.lineage_gate_count
        campaign_gate_count = [int]$candidate.campaign_gate_count
        executed_gate_count = [int]$attestation.executed_gate_count
        gate_cas_object_count = $gateCasCount
        role_bindings = $roles
    }
    return [ordered]@{
        contract = $contract
        closure = $closure
        candidate = $candidate
        source = $source
        runtime = $runtime
        attestation = $attestation
        attestation_path = $attestationResolved
        attestation_byte_length = $attestationBytes
        expected = $expected
    }
}

function Test-SporeSporeCampaignAttestationAdoptionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$AdoptionPath,
        [Parameter(Mandatory)][string]$Godot,
        [string]$Python = "python",
        [Parameter(Mandatory)][string]$ExpectedCampaignId
    )
    try {
        $adoption = Get-Content -Raw -LiteralPath $AdoptionPath |
            ConvertFrom-Json -AsHashtable -Depth 100
        $inputs = Get-SporeSporeCampaignAdoptionVerifiedInputs `
            -RepoRoot $RepoRoot -ManifestPath $ManifestPath `
            -ScopedAttestationPath ([string]$adoption.scoped_attestation.path) `
            -Godot $Godot -Python $Python -ExpectedCampaignId $ExpectedCampaignId
        $test = Test-SporeSporeCampaignAdoptionDocument `
            -Document $adoption -Expected $inputs.expected
        $actualSha = Get-SporeSporeCampaignAttestationSha256 $AdoptionPath
        return [ordered]@{
            ok = [bool]$test.ok
            failure_codes = @($test.failure_codes)
            adoption = $adoption
            sha256 = $actualSha
            source = $inputs.source
            physical_launch_prerequisite_satisfied = [bool]$test.ok
            physical_acceptance_authority = $false
            release_authority = $false
        }
    } catch {
        return [ordered]@{
            ok = $false
            failure_codes = @("VERIFICATION_EXCEPTION::$($_.Exception.Message)")
            physical_launch_prerequisite_satisfied = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }
}

function Publish-SporeSporeCampaignAttestationAdoption {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ScopedAttestationPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$Godot,
        [string]$Python = "python",
        [Parameter(Mandatory)][string]$ExpectedCampaignId
    )
    $resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
    if (Test-Path -LiteralPath $resolvedOutput) {
        throw "Campaign-attestation adoption refuses to overwrite: $resolvedOutput"
    }
    $evidenceRoot = (Get-SporeSporeArtifactEvidenceRoot -RepoRoot $RepoRoot).
        TrimEnd('\', '/')
    if (-not $resolvedOutput.StartsWith(
        $evidenceRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Campaign-attestation adoption output must be under $evidenceRoot"
    }
    $inputs = Get-SporeSporeCampaignAdoptionVerifiedInputs `
        -RepoRoot $RepoRoot -ManifestPath $ManifestPath `
        -ScopedAttestationPath $ScopedAttestationPath `
        -Godot $Godot -Python $Python -ExpectedCampaignId $ExpectedCampaignId
    $expected = $inputs.expected
    $document = [ordered]@{
        schema_version = $script:SporeSporeCampaignAdoptionSchema
        status = "commissioned_campaign_local_qualification_adopted_for_physical_launch"
        campaign_id = [string]$expected.campaign_id
        source_commit = [string]$expected.source_commit
        source_tree_git_oid = [string]$expected.source_tree_git_oid
        manifest_raw_sha256 = [string]$expected.manifest_raw_sha256
        scoped_attestation_raw_sha256 = [string]$expected.scoped_attestation_raw_sha256
        commissioning_closure_raw_sha256 = [string]$expected.commissioning_closure_raw_sha256
        commissioning_audit_raw_sha256 = [string]$expected.commissioning_audit_raw_sha256
        runtime_inventory_sha256 = [string]$expected.runtime_inventory_sha256
        candidate_inventory_sha256 = [string]$expected.candidate_inventory_sha256
        declared_physical_world_count = [int]$expected.declared_physical_world_count
        global_gate_count = [int]$expected.global_gate_count
        lineage_gate_count = [int]$expected.lineage_gate_count
        campaign_gate_count = [int]$expected.campaign_gate_count
        executed_gate_count = [int]$expected.executed_gate_count
        gate_cas_object_count = [int]$expected.gate_cas_object_count
        role_bindings = @($expected.role_bindings)
        scoped_attestation = [ordered]@{
            path = [string]$inputs.attestation_path
            raw_sha256 = [string]$expected.scoped_attestation_raw_sha256
            byte_length = [long]$inputs.attestation_byte_length
            cas_verified = $true
        }
        commissioned_executor_verified = $true
        campaign_local_attestation_verified = $true
        all_gate_cas_objects_verified = $true
        scoped_attestation_cas_verified = $true
        clean_pushed_live_source_verified = $true
        runtime_matches_commissioning = $true
        physical_launch_prerequisite_satisfied = $true
        physical_acceptance_authority = $false
        release_authority = $false
        claims = [ordered]@{
            commissioned_executor_verified = $true
            campaign_local_qualification_passed = $true
            physical_launch_prerequisite_satisfied = $true
            physical_campaign_executed = $false
            scientific_result = $false
            walking_acceptance = $false
            turning_acceptance = $false
            cross_engine_equivalence = $false
            release_authority = $false
            physical_acceptance_authority = $false
        }
    }
    $test = Test-SporeSporeCampaignAdoptionDocument `
        -Document $document -Expected $expected
    if (-not [bool]$test.ok) {
        throw "Generated adoption document failed: $(@($test.failure_codes) -join ',')"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput))
    [IO.File]::WriteAllText(
        $resolvedOutput,
        ($document | ConvertTo-Json -Depth 100 -Compress) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $cas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $RepoRoot -ArtifactPath $resolvedOutput `
        -MediaType "application/json"
    return [ordered]@{
        path = $resolvedOutput
        sha256 = [string]$cas.sha256
        byte_length = [long]$cas.byte_length
        cas = $cas
        campaign_id = $ExpectedCampaignId
        source_commit = [string]$expected.source_commit
        physical_launch_prerequisite_satisfied = $true
        physical_acceptance_authority = $false
        release_authority = $false
    }
}
