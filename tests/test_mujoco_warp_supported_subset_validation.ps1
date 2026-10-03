#requires -Version 7.0
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$manifestPath = Join-Path $repoRoot "sdk\adaptation_provider\mujoco_warp_supported_subset_validation_manifest.json"
function Assert-MjwEvidence([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "MJWARP_SUBSET_EVIDENCE $Message" } }
function Get-Sha([string]$Path) { "sha256:" + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
Assert-MjwEvidence ((git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq $repoRoot.TrimEnd("\")) "wrong root"
Assert-MjwEvidence ((git -C $repoRoot remote get-url origin).Trim() -ceq "https://github.com/Slagathore/sporespore.git") "wrong remote"
$m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 64
Assert-MjwEvidence (
  $m.schema_version -ceq "sporespore_mujoco_warp_supported_subset_validation_manifest_v1" -and
  $m.status -ceq "accepted_zero_world_runtime_preflight" -and
  $m.question_class -ceq "development" -and
  $m.source_commit -ceq "a318bdf2ba500e4614ab6f12427298bf508e4a5e" -and
  [bool]$m.source_clean -and [bool]$m.source_matches_origin_main
) "manifest identity changed"
foreach ($binding in @($m.frozen_files)) {
  $path = Join-Path $repoRoot ([string]$binding.path)
  Assert-MjwEvidence ((Test-Path -LiteralPath $path -PathType Leaf) -and (Get-Sha $path) -ceq [string]$binding.raw_sha256 -and (Get-Item $path).Length -eq [long]$binding.byte_length) "frozen file changed: $($binding.path)"
}
$reportPath = [string]$m.report.path
Assert-MjwEvidence ((Test-Path -LiteralPath $reportPath -PathType Leaf) -and (Get-Sha $reportPath) -ceq [string]$m.report.sha256 -and (Get-Item $reportPath).Length -eq [long]$m.report.byte_length) "report bytes changed"
$r = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -Depth 64
Assert-MjwEvidence (
  $r.schema_version -ceq $m.report.schema_version -and [bool]$r.ok -and
  $r.source.commit -ceq $m.source_commit -and $r.source.origin_main -ceq $m.source_commit -and
  [bool]$r.source.clean -and [bool]$r.source.matches_origin_main -and @($r.source.status_entries).Count -eq 0 -and
  $r.runtime.mujoco -ceq "3.11.0" -and $r.runtime.mujoco_warp -ceq "3.11.0" -and $r.runtime.warp_lang -ceq "1.16.0" -and
  [bool]$r.runtime.cuda_available -and @($r.runtime.devices) -ccontains "cuda:0" -and
  [int]$r.model_construction_count -eq 0 -and [int]$r.step_invocation_count -eq 0 -and [int]$r.world_build_count -eq 0 -and
  -not [bool]$r.supported_physics_subset_qualified -and -not [bool]$r.training_plane_authorized -and
  -not [bool]$r.scientific_result -and -not [bool]$r.physical_acceptance_authority -and -not [bool]$r.release_authority
) "runtime identity, zero-world boundary, or authority changed"
Assert-MjwEvidence ([bool]$m.runtime_installed -and [bool]$m.cuda_runtime_available -and -not [bool]$m.supported_physics_subset_qualified -and -not [bool]$m.training_plane_authorized -and -not [bool]$m.training_data_authority -and -not [bool]$m.scientific_result -and -not [bool]$m.physical_acceptance_authority -and -not [bool]$m.release_authority) "manifest claim boundary changed"
Write-Host "MJWARP_SUBSET_EVIDENCE_PASS source=a318bdf runtime=3.11.0 warp=1.16.0 models=0 steps=0 worlds=0 qualified=false training=false"
