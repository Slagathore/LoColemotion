#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot "sdk\turning\r23d15_stage_zero_closure_v1.json"
$sourceCommit = "51eb3d9f8ad6ef26d6e9859d8c8c9b7b93ca8cf3"
$sourceParent = "24ca52c4a2450184285f31e9f425155b4ae7b52e"
$sourceTree = "c3b933dd7e168d7dd64e8d315d57b020529a95c1"

function Assert-R23D15StageZero([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D15GitBlobMetadata([string]$BlobOid) {
    $temporary = [IO.Path]::GetTempFileName()
    try {
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = "git"
        $start.WorkingDirectory = $repoRoot
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        [void]$start.ArgumentList.Add("cat-file")
        [void]$start.ArgumentList.Add("blob")
        [void]$start.ArgumentList.Add($BlobOid)
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $start
        Assert-R23D15StageZero $process.Start() "Git blob process did not start"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $stream = [IO.File]::Open(
            $temporary,
            [IO.FileMode]::Create,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try { $process.StandardOutput.BaseStream.CopyTo($stream) }
        finally { $stream.Dispose() }
        $process.WaitForExit()
        Assert-R23D15StageZero ($process.ExitCode -eq 0) (
            "Git blob read failed: " + $stderrTask.GetAwaiter().GetResult()
        )
        return [ordered]@{
            raw_sha256 = "sha256:" + (
                Get-FileHash -Algorithm SHA256 -LiteralPath $temporary
            ).Hash.ToLowerInvariant()
            byte_length = (Get-Item -LiteralPath $temporary).Length
            text = [IO.File]::ReadAllText($temporary)
        }
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D15StageZero (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D15 stage-zero repository identity changed"
Assert-R23D15StageZero (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "QSDK-R23D15 stage-zero closure is missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D15StageZero (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d15_stage_zero_closure_v1" -and
    [string]$closure.status -ceq
        "closed_immutable_clean_pushed_stage_zero_composition_recovery_zero_world_only" -and
    [string]$closure.campaign_id -ceq (
        "QSDK-R23D15-PRODUCTION-COMPOSITION-RECOVERY-" +
        "THREE-ENGINE-TURN-CONFIRMATION"
    ) -and
    [string]$closure.gate_id -ceq "QSDK-R23D15" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23"
) "QSDK-R23D15 stage-zero closure identity changed"

$identity = $closure.source_identity
Assert-R23D15StageZero (
    [string]$identity.commit -ceq $sourceCommit -and
    [string]$identity.parent_commit -ceq $sourceParent -and
    [string]$identity.tree_git_oid -ceq $sourceTree -and
    [bool]$identity.clean_at_post_push_gate -and
    [bool]$identity.local_origin_live_main_equal_after_push -and
    [bool]$identity.published_on_main -and
    (git -C $repoRoot rev-parse "$sourceCommit^{commit}").Trim() -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit^{tree}").Trim() -ceq $sourceTree -and
    (git -C $repoRoot rev-parse "$sourceCommit^").Trim() -ceq $sourceParent
) "QSDK-R23D15 stage-zero source identity changed"

$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveMain = ((git -C $repoRoot ls-remote origin refs/heads/main) -split "\s+")[0]
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $originMain
$originContains = $LASTEXITCODE -eq 0
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $liveMain
$liveContains = $LASTEXITCODE -eq 0
Assert-R23D15StageZero ($originContains -and $liveContains) (
    "QSDK-R23D15 stage-zero source is not published on origin/live main"
)

$bindings = @($closure.source_bindings)
Assert-R23D15StageZero (
    $bindings.Count -eq 16 -and
    [int]$closure.source_binding_count -eq 16 -and
    @($bindings.path | Select-Object -Unique).Count -eq 16 -and
    @($bindings.git_blob_oid | Select-Object -Unique).Count -eq 16
) "QSDK-R23D15 stage-zero source-binding inventory changed"

$bindingText = @{}
foreach ($binding in $bindings) {
    $path = [string]$binding.path
    $blob = (git -C $repoRoot rev-parse "$sourceCommit`:$path").Trim()
    Assert-R23D15StageZero (
        $LASTEXITCODE -eq 0 -and
        $blob -ceq [string]$binding.git_blob_oid
    ) "QSDK-R23D15 stage-zero blob identity changed: $path"
    $metadata = Get-R23D15GitBlobMetadata $blob
    Assert-R23D15StageZero (
        [string]$metadata.raw_sha256 -ceq [string]$binding.raw_sha256 -and
        [long]$metadata.byte_length -eq [long]$binding.byte_length
    ) "QSDK-R23D15 stage-zero blob bytes changed: $path"
    $bindingText[$path] = [string]$metadata.text
}

$requiredRules = @(
    "sdk/turning/r23d15_* text eol=lf",
    "sdk/turning/test_r23d15_* text eol=lf",
    "sdk/run_qsdk_r23d15_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d15_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d15_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d15_*.gd text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_r23d15_*.gd text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d15_*.rs text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d15_*.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d15_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d15_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d15_*.py text eol=lf"
)
$attributes = [string]$bindingText[".gitattributes"]
foreach ($rule in $requiredRules) {
    Assert-R23D15StageZero $attributes.Contains($rule) (
        "QSDK-R23D15 stage-zero checkout rule missing: $rule"
    )
}
Assert-R23D15StageZero (
    [bool]$closure.checkout_provenance.r23d15_family_lf_rules_present_in_pinned_gitattributes -and
    [bool]$closure.checkout_provenance.all_bound_checkout_bytes_equal_pinned_git_blob_bytes_at_freeze -and
    [bool]$closure.checkout_provenance.ambient_text_auto_is_not_authority_for_r23d15_family
) "QSDK-R23D15 stage-zero checkout provenance changed"

$declaration = [string]$bindingText[
    "sdk/turning/r23d15_composition_recovery_preregistration_v1.json"
] | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D15StageZero (
    [string]$declaration.status -ceq
        "prospective_stage_zero_repair_implemented_zero_world_only" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D15" -and
    -not [bool]$declaration.frozen_scientific_question.changed_from_r23d14 -and
    -not [bool]$declaration.frozen_scientific_question.walking_turning_controller_changed -and
    -not [bool]$declaration.frozen_scientific_question.threshold_changed -and
    -not [bool]$declaration.frozen_scientific_question.horizon_changed -and
    [int]$declaration.prospective_matrix.declared_cell_count -eq 9 -and
    [bool]$declaration.prospective_matrix.serialized_execution_required -and
    -not [bool]$declaration.stage_zero_qualification.physical_execution_authorized
) "QSDK-R23D15 pinned declaration changed"

$wave = [string]$bindingText["scripts/lab/gait/physical_wave_gait_quadruped.gd"]
$rapier = [string]$bindingText[
    "sdk/adapters/rapier/src/qsdk_r23d15_composition_recovery.rs"
]
$rapierBody = [string]$bindingText[
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_physical.rs"
]
Assert-R23D15StageZero (
    $wave.Contains("static func _normalize_sdk_terminal_handoff_reason") -and
    $wave.Contains("static func run_sdk_terminal_handoff_reason_canary") -and
    $wave.Contains(
        'var handoff_reason_result := _normalize_sdk_terminal_handoff_reason('
    ) -and
    -not $wave.Contains('sdk_terminal_taper_state.get("handoff_reason", "")') -and
    $rapier.Contains('INHERITED_R23D11_STAGE_ID: &str = "three_engine_confirmation"') -and
    $rapier.Contains("predecessor_direct_binding_failure_reproduced") -and
    $rapierBody.Contains("run_qsdk_r23d15_rapier_inherited_composition_preflight(") -and
    -not $rapierBody.Contains("run_qsdk_r23d11_rapier_preflight(")
) "QSDK-R23D15 pinned mechanism recovery changed"

$gate = $closure.post_push_zero_world_gate
Assert-R23D15StageZero (
    [string]$gate.executed_from_exact_source_commit -ceq $sourceCommit -and
    [int]$gate.exit_code -eq 0 -and
    [double]$gate.elapsed_seconds -gt 0.0 -and
    [string]$gate.terminal_marker -ceq "QSDK_R23D15_STAGE_ZERO_GATE_PASS" -and
    -not [bool]$gate.scientific_question_changed -and
    [int]$gate.godot_valid_canary_count -eq 2 -and
    [int]$gate.godot_mutation_control_count -eq 1 -and
    [int]$gate.rapier_declared_arm_count -eq 3 -and
    [int]$gate.rapier_unit_test_count -eq 4 -and
    [int]$gate.physical_worker_count -eq 0 -and
    [int]$gate.model_construction_count -eq 0 -and
    [int]$gate.world_build_count -eq 0 -and
    -not [bool]$gate.physical_acceptance_authority
) "QSDK-R23D15 post-push zero-world result changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $sourceCommit)
foreach ($futurePath in @($closure.future_paths_absent_from_stage_zero_tree)) {
    Assert-R23D15StageZero ($treePaths -cnotcontains [string]$futurePath) (
        "QSDK-R23D15 stage-zero tree contained future path: $futurePath"
    )
}

$claims = $closure.claims
Assert-R23D15StageZero (
    [bool]$claims.production_composition_repair_zero_world_qualified -and
    -not [bool]$claims.finite_three_engine_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$closure.next_boundary.physical_execution_authorized
) "QSDK-R23D15 stage-zero claim boundary changed"

Write-Host (
    "QSDK_R23D15_STAGE_ZERO_CLOSURE_PASS commit=$sourceCommit " +
    "tree=$sourceTree blobs=16 rules=12 godot_canaries=2 " +
    "godot_mutations=1 rapier_arms=3 rapier_tests=4 workers=0 " +
    "models=0 worlds=0 turning=False equivalence=False physical_authority=False"
)
