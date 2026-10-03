#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$modulePath = Join-Path $sdkRoot "locomotion_campaign_attestation.ps1"
$contractPath = Join-Path $sdkRoot "locomotion_campaign_attestation_contract_v1.json"
$runnerPath = Join-Path $sdkRoot "run_locomotion_campaign_attestation.ps1"
$conformanceRunnerPath = Join-Path $sdkRoot "run_conformance.ps1"
$commissioningManifestPath = Join-Path `
    $sdkRoot "locomotion_campaign_attestation_v1_commissioning_manifest.json"

function Assert-Lca1([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LOCOMOTION_CAMPAIGN_ATTESTATION $Message" }
}

function Write-Lca1Utf8([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Write-Lca1Json([string]$Path, [object]$Value) {
    Write-Lca1Utf8 $Path (($Value | ConvertTo-Json -Depth 100) + "`n")
}

function Copy-Lca1([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-Lca1Rejected([scriptblock]$Action, [string]$Label) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    Assert-Lca1 $rejected "$Label was accepted"
}

foreach ($path in @(
    $modulePath, $contractPath, $runnerPath, $conformanceRunnerPath,
    $commissioningManifestPath, $Godot
)) {
    Assert-Lca1 (Test-Path -LiteralPath $path -PathType Leaf) `
        "required input is missing: $path"
}
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile(
    $modulePath,
    [ref]$null,
    [ref]$parseErrors
)
Assert-Lca1 ($parseErrors.Count -eq 0) "module does not parse"
. $modulePath

$contract = Get-SporeSporeCampaignAttestationContract
Assert-Lca1 (
    [string]$contract.contract_id -ceq
        "LCA1-GODOT-INCLUSIVE-CAMPAIGN-LOCAL-ATTESTATION" -and
    [int]$contract.global_kernel.required_gate_count -eq 12 -and
    @($contract.global_kernel.required_safeguards).Count -eq 12 -and
    @($contract.campaign_scope.required_negative_control_roles).Count -eq 3 -and
    [bool]$contract.commissioning.first_cold_comparison_closed_negative -and
    [bool]$contract.commissioning.second_cold_comparison_closed_negative -and
    -not [bool]$contract.commissioning.commissioned -and
    -not [bool]$contract.commissioning.physical_launch_prerequisite_may_be_satisfied -and
    -not [bool]$contract.claims.physical_acceptance_authority -and
    -not [bool]$contract.claims.release_authority
) "prospective contract boundary changed"
$commissioningCandidate = Get-SporeSporeCampaignAttestationCandidate `
    -RepoRoot $repoRoot -ManifestPath $commissioningManifestPath -TestOnly
Assert-Lca1 (
    [string]$commissioningCandidate.campaign_id -ceq
        "LCA1-COLD-COMMISSIONING-OVER-CLOSED-R23D17" -and
    [string]$commissioningCandidate.manifest.status -ceq
        "cold_commissioning_only" -and
    [int]$commissioningCandidate.declared_physical_world_count -eq 0 -and
    [int]$commissioningCandidate.global_gate_count -eq 12 -and
    [int]$commissioningCandidate.lineage_gate_count -eq 1 -and
    [int]$commissioningCandidate.campaign_gate_count -eq 3 -and
    [bool]$commissioningCandidate.campaign_roles_complete -and
    -not [bool]$commissioningCandidate.manifest.physical_launch_candidate -and
    -not [bool]$commissioningCandidate.commissioned -and
    -not [bool]$commissioningCandidate.physical_launch_prerequisite_satisfied
) "cold-commissioning manifest was malformed or inflated"

$canonicalRunnerCompact = (
    Get-Content -LiteralPath $conformanceRunnerPath -Raw
) -replace '\s', ''
Assert-Lca1 (
    $canonicalRunnerCompact.Contains(
        'foreach($commissioningRolein@("worker","evaluator","supervisor"))'
    ) -and
    $canonicalRunnerCompact.Contains(
        '"tests\test_locomotion_campaign_attestation_commissioning_roles.ps1"'
    ) -and
    $canonicalRunnerCompact.Contains(
        '-Role$commissioningRole'
    ) -and
    $canonicalRunnerCompact.Contains(
        '$commissioningRoleOutput=@(&pwsh'
    ) -and
    $canonicalRunnerCompact.Contains(
        '$commissioningRoleExitCode=$LASTEXITCODE'
    ) -and
    $canonicalRunnerCompact.Contains(
        'Write-Host([string]$line)'
    ) -and
    $canonicalRunnerCompact.Contains(
        '"tests\test_locomotion_campaign_attestation_v1_first_cold_comparison_' +
        'incident.ps1")'
    ) -and
    $canonicalRunnerCompact.Contains(
        '"tests\test_locomotion_campaign_attestation_v1_second_cold_comparison_' +
        'incident.ps1")'
    )
) "canonical full runner does not execute all three exact campaign-role edges"

$testRoot = Join-Path $sdkRoot (
    "target\locomotion-campaign-attestation-test-" +
    [guid]::NewGuid().ToString("N")
)
$testEvidence = Join-Path $testRoot "evidence"
[void][IO.Directory]::CreateDirectory($testRoot)
[void][IO.Directory]::CreateDirectory($testEvidence)
$mutexName = "Global\SporeSpore.Locomotion.Test.LCA1_" +
    [guid]::NewGuid().ToString("N")

try {
    $captureTranscript = Join-Path $testRoot "native-child-capture-transcript.txt"
    Start-Transcript -LiteralPath $captureTranscript -UseMinimalHeader | Out-Null
    try {
        $captureOutput = @(& pwsh `
            -NoLogo `
            -NoProfile `
            -File (Join-Path $repoRoot `
                "tests\test_locomotion_campaign_attestation_commissioning_roles.ps1") `
            -Role worker 2>&1)
        $captureExitCode = $LASTEXITCODE
        foreach ($line in $captureOutput) { Write-Host ([string]$line) }
    } finally {
        Stop-Transcript | Out-Null
    }
    $captureText = Get-Content -LiteralPath $captureTranscript -Raw
    Assert-Lca1 (
        $captureExitCode -eq 0 -and
        [regex]::Matches(
            $captureText,
            [regex]::Escape("LCA1_COMMISSIONING_WORKER_PASS")
        ).Count -eq 1
    ) "captured native child marker was absent from the parent transcript"

    $gateDefinitions = @(
        [ordered]@{ name = "lineage"; role = "lineage"; marker = "LCA1_LINEAGE_PASS" },
        [ordered]@{ name = "worker"; role = "worker"; marker = "LCA1_WORKER_REFUSAL_PASS" },
        [ordered]@{ name = "evaluator"; role = "evaluator"; marker = "LCA1_EVALUATOR_REFUSAL_PASS" },
        [ordered]@{ name = "supervisor"; role = "supervisor"; marker = "LCA1_SUPERVISOR_REFUSAL_PASS" }
    )
    $gates = [Collections.Generic.List[object]]::new()
    $bindings = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $gateDefinitions.Count; $index++) {
        $definition = $gateDefinitions[$index]
        $path = Join-Path $testRoot "$($definition.name).ps1"
        Write-Lca1Utf8 $path (
            "#requires -Version 7.0`n" +
            "Write-Host `"$($definition.marker) worlds=0 physical_authority=False`"`n"
        )
        $relative = $path.Substring($repoRoot.Length + 1).Replace('\', '/')
        $hash = Get-SporeSporeCampaignAttestationSha256 $path
        $gates.Add([ordered]@{
            ordinal = $index + 1
            gate_id = "LCA1-TEST-$($definition.name.ToUpperInvariant())"
            role = [string]$definition.role
            invocation_kind = "powershell_file"
            path = $relative
            arguments = @()
            terminal_marker_prefix = [string]$definition.marker
            raw_sha256 = $hash
        })
        $bindings.Add([ordered]@{ path = $relative; raw_sha256 = $hash })
    }
    $manifest = [ordered]@{
        schema_version = "sporespore_locomotion_campaign_attestation_manifest_v1"
        status = "cold_commissioning_only"
        campaign_id = "LCA1-SYNTHETIC-ZERO-WORLD-COMMISSIONING-CANARY"
        question_class = "finite_decision"
        declared_physical_world_count = 0
        physical_launch_candidate = $false
        godot_including = $true
        skip_godot = $false
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
        declared_lineage_gate_count = 1
        declared_campaign_gate_count = 3
        declared_total_gate_count = 4
        declared_role_binding_count = 3
        lineage_gates = @($gates[0])
        campaign_gates = @($gates[1..3])
        source_bindings = @($bindings)
        dependency_authority = [ordered]@{
            path = [string]$gates[0].path
            raw_sha256 = [string]$gates[0].raw_sha256
        }
        campaign_role_bindings = @(
            [ordered]@{
                role = "worker"
                source_path = [string]$gates[1].path
                source_raw_sha256 = [string]$gates[1].raw_sha256
                test_gate_id = [string]$gates[1].gate_id
                test_path = [string]$gates[1].path
                test_raw_sha256 = [string]$gates[1].raw_sha256
            },
            [ordered]@{
                role = "evaluator"
                source_path = [string]$gates[2].path
                source_raw_sha256 = [string]$gates[2].raw_sha256
                test_gate_id = [string]$gates[2].gate_id
                test_path = [string]$gates[2].path
                test_raw_sha256 = [string]$gates[2].raw_sha256
            },
            [ordered]@{
                role = "supervisor"
                source_path = [string]$gates[3].path
                source_raw_sha256 = [string]$gates[3].raw_sha256
                test_gate_id = [string]$gates[3].gate_id
                test_path = [string]$gates[3].path
                test_raw_sha256 = [string]$gates[3].raw_sha256
            }
        )
        claims = [ordered]@{
            campaign_local_qualification_passed = $false
            cold_commissioning_complete = $false
            physical_launch_prerequisite_satisfied = $false
            physical_campaign_executed = $false
            scientific_result = $false
            walking_acceptance = $false
            turning_acceptance = $false
            cross_engine_equivalence = $false
            arbitrary_quadruped_coverage = $false
            release_authority = $false
            physical_acceptance_authority = $false
        }
    }
    $manifestPath = Join-Path $testRoot "manifest.json"
    Write-Lca1Json $manifestPath $manifest
    $candidate = Get-SporeSporeCampaignAttestationCandidate `
        -RepoRoot $repoRoot -ManifestPath $manifestPath -TestOnly
    Assert-Lca1 (
        [string]$candidate.schema_version -ceq
            "sporespore_locomotion_campaign_attestation_candidate_v1" -and
        [string]$candidate.inventory_sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
        [int]$candidate.global_gate_count -eq 12 -and
        [int]$candidate.lineage_gate_count -eq 1 -and
        [int]$candidate.campaign_gate_count -eq 3 -and
        [bool]$candidate.campaign_roles_complete -and
        [bool]$candidate.godot_including -and
        -not [bool]$candidate.commissioned -and
        -not [bool]$candidate.physical_launch_prerequisite_satisfied -and
        -not [bool]$candidate.physical_acceptance_authority
    ) "candidate projection was malformed or inflated"

    $outputRoot = Join-Path $testRoot "passing-output"
    $result = Invoke-SporeSporeCampaignAttestation `
        -RepoRoot $repoRoot -ManifestPath $manifestPath -Godot $Godot `
        -OutputRoot $outputRoot -MutexName $mutexName `
        -EvidenceRootOverride $testEvidence -TestOnly -SkipGlobalGatesForTestOnly
    Assert-Lca1 (
        [bool]$result.campaign_local_qualification_passed -and
        -not [bool]$result.commissioned -and
        -not [bool]$result.physical_launch_prerequisite_satisfied -and
        -not [bool]$result.physical_acceptance_authority -and
        (Test-Path -LiteralPath $result.path -PathType Leaf) -and
        [string]$result.sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
        (Test-Path -LiteralPath $result.cas.payload_path -PathType Leaf)
    ) "test-only execution result was malformed or inflated"
    $attestation = Get-Content -LiteralPath $result.path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $testCandidate = Copy-Lca1 $candidate
    $testCandidate.global_gate_count = 0
    $testValidation = Test-SporeSporeCampaignAttestationDocument `
        -Document $attestation -Candidate $testCandidate `
        -ExpectedSource $attestation.source -ExpectedRuntime $attestation.runtime `
        -AllowTestOnly
    $productionValidation = Test-SporeSporeCampaignAttestationDocument `
        -Document $attestation -Candidate $testCandidate `
        -ExpectedSource $attestation.source -ExpectedRuntime $attestation.runtime
    Assert-Lca1 (
        [bool]$testValidation.ok -and
        -not [bool]$testValidation.physical_launch_prerequisite_satisfied -and
        -not [bool]$productionValidation.ok -and
        @($productionValidation.failure_codes) -ccontains "TEST_ONLY_FORBIDDEN" -and
        @($attestation.gate_receipts).Count -eq 4 -and
        @($attestation.gate_receipts | Where-Object {
            -not [bool]$_.passed -or [int]$_.terminal_marker_count -ne 1 -or
            -not (Test-Path -LiteralPath $_.stdout_cas.payload_path -PathType Leaf) -or
            -not (Test-Path -LiteralPath $_.stderr_cas.payload_path -PathType Leaf) -or
            -not (Test-Path -LiteralPath $_.receipt_cas.payload_path -PathType Leaf)
        }).Count -eq 0
    ) "serialized test attestation or CAS retention failed"

    Assert-Lca1Rejected {
        [void](Invoke-SporeSporeCampaignAttestation `
            -RepoRoot $repoRoot -ManifestPath $manifestPath -Godot $Godot `
            -OutputRoot $outputRoot -MutexName $mutexName `
            -EvidenceRootOverride $testEvidence -TestOnly -SkipGlobalGatesForTestOnly)
    } "create-only output overwrite"
    Assert-Lca1Rejected {
        [void](Invoke-SporeSporeCampaignAttestation `
            -RepoRoot $repoRoot -ManifestPath $manifestPath -Godot $Godot `
            -OutputRoot (Join-Path $testRoot "production-skip") `
            -SkipGlobalGatesForTestOnly)
    } "production global-gate skip"
    Assert-Lca1Rejected {
        [void](Assert-SporeSporeCampaignAttestationOutputRoot `
            -RepoRoot $repoRoot -OutputRoot (Join-Path $testRoot "not-durable"))
    } "production nondurable output"

    $mutations = [Collections.Generic.List[object]]::new()
    $inflated = Copy-Lca1 $manifest
    $inflated.claims.physical_acceptance_authority = $true
    $mutations.Add([ordered]@{ name = "claim inflation"; value = $inflated })
    $duplicate = Copy-Lca1 $manifest
    $duplicate.campaign_gates[0].gate_id = [string]$duplicate.lineage_gates[0].gate_id
    $mutations.Add([ordered]@{ name = "duplicate gate"; value = $duplicate })
    $digest = Copy-Lca1 $manifest
    $digest.campaign_gates[0].raw_sha256 = "sha256:" + ("0" * 64)
    $mutations.Add([ordered]@{ name = "gate digest"; value = $digest })
    $binding = Copy-Lca1 $manifest
    $binding.source_bindings[0].raw_sha256 = "sha256:" + ("1" * 64)
    $mutations.Add([ordered]@{ name = "source binding digest"; value = $binding })
    $escape = Copy-Lca1 $manifest
    $escape.campaign_gates[0].path = "../outside.ps1"
    $mutations.Add([ordered]@{ name = "path escape"; value = $escape })
    $unsafe = Copy-Lca1 $manifest
    $unsafe.campaign_gates[0].arguments = @("-RunPhysical")
    $mutations.Add([ordered]@{ name = "physical argument"; value = $unsafe })
    $missingRole = Copy-Lca1 $manifest
    $missingRole.campaign_gates[0].role = "evaluator"
    $mutations.Add([ordered]@{ name = "missing worker role"; value = $missingRole })
    $roleSource = Copy-Lca1 $manifest
    $roleSource.campaign_role_bindings[0].source_raw_sha256 =
        "sha256:" + ("2" * 64)
    $mutations.Add([ordered]@{ name = "role source digest"; value = $roleSource })
    $wrongOrder = Copy-Lca1 $manifest
    $wrongOrder.campaign_gates[0].ordinal = 9
    $mutations.Add([ordered]@{ name = "gate order"; value = $wrongOrder })
    foreach ($mutation in $mutations) {
        $mutationPath = Join-Path $testRoot (
            "mutation-" + ([string]$mutation.name -replace '[^A-Za-z0-9]', '-') + ".json"
        )
        Write-Lca1Json $mutationPath $mutation.value
        Assert-Lca1Rejected {
            [void](Get-SporeSporeCampaignAttestationCandidate `
                -RepoRoot $repoRoot -ManifestPath $mutationPath -TestOnly)
        } ([string]$mutation.name)
    }

    $duplicateMarkerManifest = Copy-Lca1 $manifest
    $workerPath = Join-Path $testRoot "worker.ps1"
    Write-Lca1Utf8 $workerPath (
        "Write-Host `"LCA1_WORKER_REFUSAL_PASS first`"`n" +
        "Write-Host `"LCA1_WORKER_REFUSAL_PASS duplicate`"`n"
    )
    $workerHash = Get-SporeSporeCampaignAttestationSha256 $workerPath
    $duplicateMarkerManifest.campaign_gates[0].raw_sha256 = $workerHash
    foreach ($entry in $duplicateMarkerManifest.source_bindings) {
        if ([string]$entry.path -ceq [string]$duplicateMarkerManifest.campaign_gates[0].path) {
            $entry.raw_sha256 = $workerHash
        }
    }
    $duplicateMarkerManifest.campaign_role_bindings[0].source_raw_sha256 =
        $workerHash
    $duplicateMarkerManifest.campaign_role_bindings[0].test_raw_sha256 =
        $workerHash
    $duplicateMarkerPath = Join-Path $testRoot "duplicate-marker.json"
    Write-Lca1Json $duplicateMarkerPath $duplicateMarkerManifest
    $failedOutput = Join-Path $testRoot "failed-output"
    Assert-Lca1Rejected {
        [void](Invoke-SporeSporeCampaignAttestation `
            -RepoRoot $repoRoot -ManifestPath $duplicateMarkerPath -Godot $Godot `
            -OutputRoot $failedOutput -MutexName $mutexName `
            -EvidenceRootOverride $testEvidence -TestOnly -SkipGlobalGatesForTestOnly)
    } "duplicate terminal marker execution"
    Assert-Lca1 (
        (Test-Path -LiteralPath (Join-Path $failedOutput "failure.json") -PathType Leaf) -and
        (Test-Path -LiteralPath (
            Join-Path $failedOutput "002-LCA1-TEST-WORKER.receipt.json"
        ) -PathType Leaf)
    ) "failed gate did not retain its failure and gate receipts"

    Write-Host (
        "LOCOMOTION_CAMPAIGN_ATTESTATION_PASS global_gates=12 lineage=1 " +
        "campaign_roles=3 synthetic_executed=4 mutations=9 " +
        "duplicate_marker_rejected=True streams_cas=True create_only=True " +
        "godot_including=True full_runner_role_edges=3 transcript_capture=True " +
        "commissioned=False " +
        "physical_prerequisite=False " +
        "worlds=0 physical_authority=False release_authority=False"
    )
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [IO.Path]::GetFullPath($testRoot)
        $target = [IO.Path]::GetFullPath((Join-Path $sdkRoot "target")).TrimEnd('\', '/')
        Assert-Lca1 (
            $resolved.StartsWith(
                $target + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $resolved) -like
                "locomotion-campaign-attestation-test-*"
        ) "refusing unsafe test cleanup"
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
