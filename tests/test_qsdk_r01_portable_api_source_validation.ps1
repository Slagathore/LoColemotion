#requires -Version 7.0

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..")
)
$manifestPath = Join-Path (
    $repoRoot
) "sdk\portable_api\portable_api_validation_manifest.json"
$contractPath = Join-Path (
    $repoRoot
) "sdk\portable_api\portable_api_contract_v1.json"
$inventoryPath = Join-Path (
    $repoRoot
) "sdk\release\quadruped_package_source_inventory_v1.json"
$releaseContractPath = Join-Path (
    $repoRoot
) "sdk\release\quadruped_release_contract.json"
$sdk1MappingPath = Join-Path (
    $repoRoot
) "sdk\release\quadruped_sdk1_milestone_mapping_v1.json"
$bridgeClosurePath = Join-Path (
    $repoRoot
) "sdk\release\qsdk_r01_sdk1_candidate_bridge_closure_v1.json"

function Assert-R01Source {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Read-JsonObject {
    param([string]$Path)
    try {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    } catch {
        throw "Invalid JSON at ${Path}: $($_.Exception.Message)"
    }
    Assert-R01Source (
        $null -ne $value -and $value -is [pscustomobject]
    ) "Expected a JSON object at $Path"
    return $value
}

function Get-BytesSha256 {
    param([byte[]]$Bytes)
    return (
        "sha256:" +
        [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($Bytes)
        ).ToLowerInvariant()
    )
}

function Get-FileSha256 {
    param([string]$Path)
    return (
        "sha256:" +
        (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    )
}

function Get-GitBlobBytes {
    param(
        [string]$Commit,
        [string]$Path
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("-C")
    [void]$start.ArgumentList.Add($repoRoot)
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add("${Commit}:$Path")
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $errorText = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R01Source (
            $process.ExitCode -eq 0
        ) "Could not read source binding ${Commit}:$Path ($errorText)"
        return [byte[]]$memory.ToArray()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

foreach ($path in @(
    $manifestPath,
    $contractPath,
    $inventoryPath,
    $releaseContractPath,
    $sdk1MappingPath,
    $bridgeClosurePath
)) {
    Assert-R01Source (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Required R01 source-validation authority is missing: $path"
}

$manifest = Read-JsonObject -Path $manifestPath
$contract = Read-JsonObject -Path $contractPath
$inventory = Read-JsonObject -Path $inventoryPath
$releaseContract = Read-JsonObject -Path $releaseContractPath
$sdk1Mapping = Read-JsonObject -Path $sdk1MappingPath
$bridgeClosure = Read-JsonObject -Path $bridgeClosurePath
$expectedCommit = "fa3e6aaefe0bc6b6d80135e870da6adb2bb19530"
$expectedTree = "8bb8f880a8fbcdc03762a8042089c8c3790b32a1"
$expectedReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\sdk-portable-api-fa3e6aae\report.json"
)
$expectedReportSha256 =
    "sha256:ee2a7bbdebc432449b152c3233522f758c445be547260fc900cef979029ed087"
$expectedReportByteLength = 4119
$expectedBindingPaths = @(
    "sdk/portable_api/README.md",
    "sdk/portable_api/conformance.py",
    "sdk/portable_api/portable_api_contract_v1.json",
    "sdk/portable_api/test_conformance.py",
    "sdk/release/quadruped_package_source_inventory_v1.json",
    "sdk/run_portable_api_conformance.ps1",
    "sdk/package_quadruped_sdk.ps1",
    "sdk/run_conformance.ps1",
    "sdk/core/Cargo.toml",
    "sdk/core/src/ffi.rs",
    "sdk/include/sporespore_locomotion.h",
    "sdk/python/sporespore_locomotion.py",
    "sdk/python/test_ctypes_smoke.py",
    "sdk/release/assert_quadruped_sdk1_candidate_authority.ps1",
    "sdk/release/qsdk_r01_sdk1_candidate_bridge_design_v1.json",
    "sdk/compile_quadruped_sdk1_milestone_readiness.ps1",
    "sdk/release/quadruped_sdk1_milestone_mapping_v1.json",
    "sdk/run_developer_experience_conformance.ps1",
    "sdk/test_quadruped_sdk_release_readiness.ps1",
    "tests/test_qsdk_r01_sdk1_candidate_bridge.ps1"
)
$expectedBridgeBindingPaths = @(
    "sdk/package_quadruped_sdk.ps1",
    "sdk/release/assert_quadruped_sdk1_candidate_authority.ps1",
    "sdk/release/qsdk_r01_sdk1_candidate_bridge_design_v1.json",
    "sdk/release/quadruped_package_source_inventory_v1.json",
    "sdk/run_developer_experience_conformance.ps1",
    "sdk/run_portable_api_conformance.ps1",
    "sdk/test_quadruped_sdk_release_readiness.ps1",
    "tests/test_qsdk_r01_sdk1_candidate_bridge.ps1"
)

Assert-R01Source (
    [string]$manifest.schema_version -ceq
        "sporespore_portable_api_validation_manifest_v1" -and
    [string]$manifest.status -ceq
        "clean_pushed_source_conformance_passed_clean_room_candidate_pending" -and
    [string]$manifest.release_gate_id -ceq "QSDK-R01" -and
    [string]$manifest.sdk1_milestone_id -ceq "SDK1-M01" -and
    [string]$manifest.ledger_scope.subsystem -ceq "release" -and
    [string]$manifest.ledger_scope.engine_scope -ceq "engine_neutral" -and
    [string]$manifest.ledger_scope.authority_mode -ceq
        "zero_world_source_conformance" -and
    [string]$manifest.ledger_scope.question_class -ceq "development"
) "R01 source-validation identity or ledger scope changed"

$source = $manifest.source
$observedTree = (& git -C $repoRoot rev-parse ($expectedCommit + "^{tree}")).Trim()
Assert-R01Source (
    $LASTEXITCODE -eq 0 -and
    [string]$source.commit -ceq $expectedCommit -and
    [string]$source.tree_oid -ceq $expectedTree -and
    $observedTree -ceq $expectedTree -and
    [string]$source.remote_url -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$source.origin_main -ceq $expectedCommit -and
    [string]$source.live_origin_main -ceq $expectedCommit -and
    [bool]$source.clean -and
    [bool]$source.matches_origin_main -and
    [bool]$source.matches_live_origin_main
) "R01 source freeze no longer proves the exact clean pushed implementation"

$bindings = @($manifest.source_bindings)
Assert-R01Source (
    $bindings.Count -eq 20 -and
    @($bindings.path | Select-Object -Unique).Count -eq $bindings.Count -and
    (@($bindings.path) -join "|") -ceq ($expectedBindingPaths -join "|")
) "R01 source-binding set changed"
foreach ($binding in $bindings) {
    $observedBlobOid = (& git -C $repoRoot rev-parse (
        "${expectedCommit}:$([string]$binding.path)"
    )).Trim()
    [byte[]]$bytes = Get-GitBlobBytes `
        -Commit $expectedCommit `
        -Path ([string]$binding.path)
    Assert-R01Source (
        $LASTEXITCODE -eq 0 -and
        $observedBlobOid -ceq [string]$binding.blob_oid -and
        $bytes.Length -eq [long]$binding.byte_length -and
        (Get-BytesSha256 -Bytes $bytes) -ceq [string]$binding.sha256
    ) "R01 source binding drifted: $($binding.path)"
}

Assert-R01Source (
    [string]$bridgeClosure.schema_version -ceq
        "sporespore_qsdk_r01_sdk1_candidate_bridge_closure_v1" -and
    [string]$bridgeClosure.status -ceq
        "closed_zero_world_bridge_qualified_candidate_execution_blocked" -and
    [string]$bridgeClosure.ledger_scope.subsystem -ceq "release" -and
    [string]$bridgeClosure.ledger_scope.engine_scope -ceq "engine_neutral" -and
    [string]$bridgeClosure.ledger_scope.authority_mode -ceq
        "bounded_sdk1_candidate_preparation_closure" -and
    [string]$bridgeClosure.ledger_scope.question_class -ceq "development" -and
    [string]$bridgeClosure.implementation_source.commit -ceq $expectedCommit -and
    [string]$bridgeClosure.implementation_source.tree_oid -ceq $expectedTree -and
    [bool]$bridgeClosure.implementation_source.clean -and
    [bool]$bridgeClosure.implementation_source.matches_origin_main -and
    [bool]$bridgeClosure.implementation_source.matches_live_origin_main
) "R01 SDK1 bridge closure identity or source boundary changed"
$bridgeBindings = @($bridgeClosure.bound_implementation)
Assert-R01Source (
    $bridgeBindings.Count -eq 8 -and
    @($bridgeBindings.path | Select-Object -Unique).Count -eq 8 -and
    (@($bridgeBindings.path) -join "|") -ceq
        ($expectedBridgeBindingPaths -join "|")
) "R01 SDK1 bridge binding population changed"
foreach ($binding in $bridgeBindings) {
    $observedBlobOid = (& git -C $repoRoot rev-parse (
        "${expectedCommit}:$([string]$binding.path)"
    )).Trim()
    [byte[]]$bytes = Get-GitBlobBytes `
        -Commit $expectedCommit `
        -Path ([string]$binding.path)
    Assert-R01Source (
        $LASTEXITCODE -eq 0 -and
        $observedBlobOid -ceq [string]$binding.blob_oid -and
        $bytes.Length -eq [long]$binding.byte_length -and
        (Get-BytesSha256 -Bytes $bytes) -ceq [string]$binding.raw_sha256
    ) "R01 SDK1 bridge source binding drifted: $($binding.path)"
}

$reportPath = [System.IO.Path]::GetFullPath([string]$manifest.report.path)
Assert-R01Source (
    $reportPath -ceq $expectedReportPath -and
    [string]$manifest.report.sha256 -ceq $expectedReportSha256 -and
    [long]$manifest.report.byte_length -eq $expectedReportByteLength -and
    (Test-Path -LiteralPath $reportPath -PathType Leaf)
) "Retained R01 source report is missing: $reportPath"
$reportItem = Get-Item -LiteralPath $reportPath
$report = Read-JsonObject -Path $reportPath
Assert-R01Source (
    $reportItem.Length -eq $expectedReportByteLength -and
    (Get-FileSha256 -Path $reportPath) -ceq $expectedReportSha256 -and
    [string]$report.schema_version -ceq
        "sporespore_portable_api_conformance_report_v1" -and
    [string]$report.status -ceq
        "source_conformance_passed_clean_room_candidate_pending" -and
    [string]$report.release_gate_id -ceq "QSDK-R01" -and
    [string]$report.sdk1_milestone_id -ceq "SDK1-M01" -and
    [string]$report.source.commit -ceq $expectedCommit -and
    [string]$report.source.origin_main -ceq $expectedCommit -and
    [string]$report.source.live_origin_main -ceq $expectedCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [bool]$report.source.matches_live_origin_main -and
    [bool]$report.source_conformance_passed -and
    -not [bool]$report.clean_room_candidate_validated -and
    -not [bool]$report.r01_passed -and
    -not [bool]$report.sdk1_m01_passed
) "Retained R01 source report identity or disposition changed"

$supersededDiagnostics = @($manifest.superseded_source_diagnostics)
Assert-R01Source (
    $supersededDiagnostics.Count -eq 2 -and
    [string]$supersededDiagnostics[0].source_commit -ceq
        "767194d57ce4c2719cae423867495419469159cf" -and
    [bool]$supersededDiagnostics[0].preserved -and
    -not [bool]$supersededDiagnostics[0].current_authority -and
    [string]$supersededDiagnostics[0].superseded_by_source_commit -ceq
        "5fe95a60b3e5021e87b7f025994f1ad56e441540" -and
    [string]$supersededDiagnostics[1].source_commit -ceq
        "5fe95a60b3e5021e87b7f025994f1ad56e441540" -and
    [bool]$supersededDiagnostics[1].preserved -and
    -not [bool]$supersededDiagnostics[1].current_authority -and
    [string]$supersededDiagnostics[1].superseded_by_source_commit -ceq
        $expectedCommit
) "Initial R01 diagnostic supersession record changed"
$expectedSupersededReports = @(
    [ordered]@{
        path = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\sdk-portable-api-767194d5\report.json"
        sha256 = "sha256:b8d281c802e56b6dce5615837023d703e7bfcf5a442b98430e3e4a235dbb0fe9"
        byte_length = 4081
    },
    [ordered]@{
        path = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\sdk-portable-api-5fe95a60\report.json"
        sha256 = "sha256:ed7091fa8dbf69dcb1b7df1e361b7a373a2d4957c620de7df26ce8b5ba2220f5"
        byte_length = 4119
    }
)
for ($diagnosticIndex = 0; $diagnosticIndex -lt 2; $diagnosticIndex++) {
    $supersededReportPath = [System.IO.Path]::GetFullPath(
        [string]$supersededDiagnostics[$diagnosticIndex].report_path
    )
    $expectedSuperseded = $expectedSupersededReports[$diagnosticIndex]
    Assert-R01Source (
        $supersededReportPath -ceq [System.IO.Path]::GetFullPath(
            [string]$expectedSuperseded.path
        ) -and
        [string]$supersededDiagnostics[$diagnosticIndex].report_sha256 -ceq
            [string]$expectedSuperseded.sha256 -and
        [long]$supersededDiagnostics[$diagnosticIndex].report_byte_length -eq
            [long]$expectedSuperseded.byte_length -and
        (Test-Path -LiteralPath $supersededReportPath -PathType Leaf)
    ) "Superseded R01 diagnostic was not preserved"
    $supersededReportItem = Get-Item -LiteralPath $supersededReportPath
    Assert-R01Source (
        $supersededReportItem.Length -eq
            [long]$supersededDiagnostics[$diagnosticIndex].report_byte_length -and
        (Get-FileSha256 -Path $supersededReportPath) -ceq
            [string]$supersededDiagnostics[$diagnosticIndex].report_sha256
    ) "Superseded R01 diagnostic bytes changed"
}

$counts = $manifest.counts
$reportConformance = $report.conformance
Assert-R01Source (
    [int]$counts.conformance_cell_count -eq 8 -and
    [int]$counts.passed_conformance_cell_count -eq 8 -and
    [int]$counts.failed_conformance_cell_count -eq 0 -and
    [int]$counts.contract_symbol_count -eq 58 -and
    [int]$counts.rust_export_count -eq 58 -and
    [int]$counts.c_declaration_count -eq 58 -and
    [int]$counts.python_ctypes_signature_count -eq 58 -and
    [int]$counts.dynamic_library_resolved_export_count -eq 58 -and
    [int]$counts.dynamic_library_invoked_export_count -eq 58 -and
    [int]$counts.buffer_protocol_symbol_count -eq 55 -and
    [int]$counts.typed_malformed_json_refusal_count -eq 52 -and
    [int]$counts.output_only_success_count -eq 4 -and
    [int]$counts.rust_unit_test_count -eq 193 -and
    [int]$counts.python_ctypes_test_count -eq 21 -and
    [int]$counts.surface_positive_control_count -eq 1 -and
    [int]$counts.surface_mutation_rejection_count -eq 10 -and
    [int]$reportConformance.passed_cell_count -eq 8 -and
    [int]$reportConformance.failed_cell_count -eq 0 -and
    [int]$reportConformance.rust_unit_test_count -eq 193 -and
    [int]$reportConformance.python_ctypes_test_count -eq 21 -and
    [int]$reportConformance.dynamic_library_invoked_export_count -eq 58 -and
    [int]$reportConformance.dynamic_typed_malformed_json_refusal_count -eq 52 -and
    [int]$reportConformance.dynamic_output_only_success_count -eq 4
) "R01 retained conformance counts changed"

$projection = $manifest.package_source_projection
$reportProjection = $report.package_projection
Assert-R01Source (
    [string]$projection.authority -ceq "git_tracked_inventory" -and
    [int]$projection.file_count -eq 1467 -and
    [long]$projection.total_byte_length -eq 31157392 -and
    [string]$projection.canonical_path_sha256_digest -ceq
        "sha256:97c3683cf4b5efb03d7902a8481efb0f56dd5c3d7e51c2ea0fbc886861a6d873" -and
    [int]$projection.required_portable_api_path_count -eq 21 -and
    [bool]$projection.all_required_portable_api_paths_present -and
    [bool]$projection.all_file_hashes_verified -and
    [string]$reportProjection.authority -ceq [string]$projection.authority -and
    [int]$reportProjection.file_count -eq [int]$projection.file_count -and
    [long]$reportProjection.total_byte_length -eq [long]$projection.total_byte_length -and
    [string]$reportProjection.canonical_path_sha256_digest -ceq
        [string]$projection.canonical_path_sha256_digest -and
    -not [bool]$reportProjection.isolated_from_source_repository -and
    -not [bool]$reportProjection.package_inventory_and_isolation_passed
) "R01 package-source projection changed or was over-promoted"

Assert-R01Source (
    [string]$report.contract.sha256 -ceq
        "sha256:07d9c526eb1558b2ee6fe4dc25ff0165e92bd41acc652ec96de4fcdc8ef003c2" -and
    [string]$report.package_source_inventory.sha256 -ceq
        "sha256:c023d50e893cd5479120ebcc4ac7a43f965dce56411118f1d36cb74b65290916" -and
    [string]$contract.schema_version -ceq
        "sporespore_portable_api_contract_v1" -and
    [string]$inventory.schema_version -ceq
        "sporespore_quadruped_package_source_inventory_v1" -and
    -not [bool]$contract.claim_boundary.r01_passed -and
    -not [bool]$contract.claim_boundary.sdk1_m01_passed
) "R01 contract or inventory identity changed"

$execution = $report.execution
Assert-R01Source (
    [int]$execution.physics_engine_process_count -eq 0 -and
    [int]$execution.physics_model_construction_count -eq 0 -and
    [int]$execution.world_build_count -eq 0 -and
    [int]$execution.native_physics_read_count -eq 0 -and
    [int]$execution.solver_step_count -eq 0 -and
    -not [bool]$report.claims.release_authorized -and
    -not [bool]$report.claims.publication_authorized -and
    -not [bool]$report.claims.walking_acceptance -and
    -not [bool]$report.claims.physical_acceptance_authority -and
    -not [bool]$report.claims.completed_engine_neutral_sdk
) "R01 source report exceeded its zero-world claim boundary"

$r01 = @(
    $releaseContract.gates |
        Where-Object { [string]$_.gate_id -ceq "QSDK-R01" }
)
$m01 = @(
    $sdk1Mapping.sdk1_contract.milestones |
        Where-Object { [string]$_.milestone_id -ceq "SDK1-M01" }
)
Assert-R01Source (
    $r01.Count -eq 1 -and
    [string]$r01[0].proof.kind -ceq "missing" -and
    [bool]$r01[0].requires_clean_room_candidate -and
    $m01.Count -eq 1 -and
    [string]$m01[0].source.kind -ceq "full_program_gate" -and
    [string]$m01[0].source.gate_id -ceq "QSDK-R01" -and
    [bool]$manifest.pending_package_boundary.candidate_runner_implemented -and
    [bool]$manifest.pending_package_boundary.bounded_sdk1_candidate_authority_bridge_implemented -and
    [bool]$manifest.pending_package_boundary.bounded_sdk1_candidate_authority_positive_shape_passed -and
    [int]$manifest.pending_package_boundary.bounded_sdk1_candidate_authority_mutation_refusal_count -eq 13 -and
    [bool]$manifest.pending_package_boundary.forged_retained_authority_failed_live_reauthorization -and
    -not [bool]$manifest.pending_package_boundary.candidate_runner_executed -and
    [bool]$manifest.pending_package_boundary.candidate_authorization_report_required -and
    -not [bool]$manifest.pending_package_boundary.candidate_creation_authorized_by_this_record -and
    -not [bool]$manifest.pending_package_boundary.clean_room_candidate_validated -and
    -not [bool]$manifest.pending_package_boundary.package_inventory_and_isolation_passed -and
    -not [bool]$manifest.pending_package_boundary.r01_passed -and
    -not [bool]$manifest.pending_package_boundary.sdk1_m01_passed -and
    -not [bool]$manifest.pending_package_boundary.physical_work_required -and
    (@($manifest.pending_package_boundary.current_candidate_blocking_milestone_ids) -join "|") -ceq
        "SDK1-M07|SDK1-M08|SDK1-M14|SDK1-M20"
) "R01 or M01 was promoted before isolated-package validation"

$bridgeQualification = $bridgeClosure.bridge_qualification
$bridgeClaims = $bridgeClosure.claims
$bridgeExecution = $bridgeClosure.execution
Assert-R01Source (
    [string]$bridgeClosure.retained_source_report.path -ceq
        [string]$manifest.report.path -and
    [string]$bridgeClosure.retained_source_report.sha256 -ceq
        $expectedReportSha256 -and
    [long]$bridgeClosure.retained_source_report.byte_length -eq
        $expectedReportByteLength -and
    [bool]$bridgeQualification.positive_authorization_shape_passed -and
    [int]$bridgeQualification.mutation_refusal_count -eq 13 -and
    [bool]$bridgeQualification.forged_retained_authority_failed_live_reauthorization -and
    [bool]$bridgeQualification.conflicting_candidate_modes_refused -and
    [int]$bridgeQualification.rejected_test_package_count -eq 0 -and
    [int]$bridgeQualification.release_readiness_contract_gate_count -eq 33 -and
    [bool]$bridgeQualification.release_readiness_suite_passed -and
    [int]$bridgeQualification.portable_conformance_passed_cell_count -eq 8 -and
    [int]$bridgeQualification.dynamic_library_invoked_export_count -eq 58 -and
    [int]$bridgeQualification.rust_unit_test_count -eq 193 -and
    [int]$bridgeQualification.python_ctypes_test_count -eq 21 -and
    [int]$bridgeQualification.package_source_file_count -eq 1467 -and
    [long]$bridgeQualification.package_source_total_byte_length -eq 31157392
) "R01 SDK1 bridge qualification or retained report changed"
Assert-R01Source (
    (@($bridgeClosure.candidate_boundary.current_blocking_milestone_ids) -join "|") -ceq
        "SDK1-M07|SDK1-M08|SDK1-M14|SDK1-M20" -and
    -not [bool]$bridgeClosure.candidate_boundary.candidate_authorized -and
    -not [bool]$bridgeClosure.candidate_boundary.candidate_created -and
    -not [bool]$bridgeClosure.candidate_boundary.candidate_conformance_executed -and
    [bool]$bridgeClaims.source_conformance_passed -and
    [bool]$bridgeClaims.bounded_sdk1_candidate_bridge_qualified -and
    -not [bool]$bridgeClaims.q_sdk_r01_satisfied -and
    -not [bool]$bridgeClaims.sdk1_m01_satisfied -and
    [string]$bridgeClaims.sdk1_score -ceq "13/20" -and
    [string]$bridgeClaims.full_program_score -ceq "13/25" -and
    -not [bool]$bridgeClaims.score_changed -and
    -not [bool]$bridgeClaims.release_authorized -and
    -not [bool]$bridgeClaims.publication_authorized -and
    [int]$bridgeExecution.physics_engine_process_count -eq 0 -and
    [int]$bridgeExecution.physics_model_construction_count -eq 0 -and
    [int]$bridgeExecution.world_build_count -eq 0 -and
    [int]$bridgeExecution.native_physics_read_count -eq 0 -and
    [int]$bridgeExecution.solver_step_count -eq 0
) "R01 SDK1 bridge closure exceeded its blocked zero-world claim boundary"

Write-Host (
    "QSDK_R01_SOURCE_VALIDATION passed=1 source_commit=$expectedCommit " +
    "symbols=58 invoked=58 rust_tests=193 python_tests=21 " +
    "mutation_refusals=10 bridge_refusals=13 package_files=1467 " +
    "worlds=0 solver_steps=0 " +
    "r01_passed=0 sdk1_m01_passed=0"
)
