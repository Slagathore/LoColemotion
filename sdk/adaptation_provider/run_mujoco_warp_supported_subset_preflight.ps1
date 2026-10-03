#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$RequireRuntime,
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$contractPath = Join-Path $PSScriptRoot "mujoco_warp_supported_subset_contract_v1.json"
$pythonPath = Join-Path $repoRoot "sdk\adapters\mujoco\.venv\Scripts\python.exe"

function Assert-Mjw([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "MJWARP_SUBSET_PREFLIGHT $Message" }
}

Assert-Mjw ((git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq $repoRoot.TrimEnd("\")) "wrong repository root"
Assert-Mjw ((git -C $repoRoot remote get-url origin).Trim() -ceq "https://github.com/Slagathore/sporespore.git") "wrong origin remote"
$statusEntries = @(git -C $repoRoot status --short)
$source = [ordered]@{
    commit = (git -C $repoRoot rev-parse HEAD).Trim()
    origin_main = (git -C $repoRoot rev-parse origin/main).Trim()
    clean = $statusEntries.Count -eq 0
    matches_origin_main = (
        (git -C $repoRoot rev-parse HEAD).Trim() -ceq
        (git -C $repoRoot rev-parse origin/main).Trim()
    )
    status_entries = $statusEntries
}
Assert-Mjw (Test-Path -LiteralPath $contractPath -PathType Leaf) "contract missing"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -Depth 64
Assert-Mjw (
    $contract.schema_version -ceq "sporespore_mujoco_warp_supported_subset_contract_v1" -and
    $contract.status -ceq "prospective_zero_world_runtime_preflight_physics_qualification_sealed" -and
    $contract.question_class -ceq "development" -and
    $contract.future_physics_qualification.question_class -ceq "equivalence_non_inferiority" -and
    -not [bool]$contract.future_physics_qualification.physical_series_open
) "contract identity or sealed question boundary changed"
foreach ($claim in $contract.claims.psobject.Properties) {
    Assert-Mjw (-not [bool]$claim.Value) "contract claim became true: $($claim.Name)"
}
Assert-Mjw (
    [int]$contract.runtime_preflight.model_construction_count -eq 0 -and
    [int]$contract.runtime_preflight.step_invocation_count -eq 0 -and
    [int]$contract.runtime_preflight.world_attempt_count -eq 0 -and
    [int]$contract.runtime_preflight.world_build_count -eq 0 -and
    -not [bool]$contract.runtime_preflight.physics_state_modified
) "zero-world boundary changed"

$runtime = $null
if ($RequireRuntime) {
    Assert-Mjw (Test-Path -LiteralPath $pythonPath -PathType Leaf) "project-local MuJoCo Python is missing"
    $probe = @'
import inspect, json
import mujoco
import mujoco_warp as mjw
import warp as wp
wp.config.log_level = wp.LOG_WARNING
wp.init()
def signature(value):
    return str(inspect.signature(value))
print("MJWARP_RUNTIME_JSON " + json.dumps({
    "mujoco": mujoco.__version__,
    "mujoco_warp": mjw.__version__,
    "warp_lang": wp.__version__,
    "cuda_available": bool(wp.is_cuda_available()),
    "devices": [str(device) for device in wp.get_devices()],
    "preferred_device": str(wp.get_preferred_device()),
    "put_model_signature": signature(mjw.put_model),
    "put_data_signature": signature(mjw.put_data),
    "step_signature": signature(mjw.step),
    "reset_data_signature": signature(mjw.reset_data),
}, sort_keys=True))
'@
    $lines = @($probe | & $pythonPath -)
    Assert-Mjw ($LASTEXITCODE -eq 0) "runtime probe failed"
    $prefix = "MJWARP_RUNTIME_JSON "
    $matches = @($lines | Where-Object { $_ -is [string] -and $_.StartsWith($prefix, [StringComparison]::Ordinal) })
    Assert-Mjw ($matches.Count -eq 1) "runtime probe emitted no unique receipt"
    $runtime = $matches[0].Substring($prefix.Length) | ConvertFrom-Json
    Assert-Mjw (
        $runtime.mujoco -ceq $contract.runtime_pin.mujoco -and
        $runtime.mujoco_warp -ceq $contract.runtime_pin.mujoco_warp -and
        $runtime.warp_lang -ceq $contract.runtime_pin.warp_lang -and
        [bool]$runtime.cuda_available -and
        @($runtime.devices) -ccontains "cuda:0" -and
        $runtime.preferred_device -ceq "cuda:0" -and
        $runtime.put_model_signature.Contains("batch_sizes", [StringComparison]::Ordinal) -and
        $runtime.put_data_signature.Contains("nworld", [StringComparison]::Ordinal) -and
        $runtime.step_signature -ceq "(m: mujoco_warp._src.types.Model, d: mujoco_warp._src.types.Data)"
    ) "runtime version, CUDA device, or API surface changed"
}

$receipt = [ordered]@{
    schema_version = "sporespore_mujoco_warp_supported_subset_preflight_receipt_v1"
    ok = $true
    contract_id = $contract.contract_id
    contract_raw_sha256 = "sha256:" + (Get-FileHash $contractPath -Algorithm SHA256).Hash.ToLowerInvariant()
    question_class = "development"
    source = $source
    runtime_required = [bool]$RequireRuntime
    runtime = $runtime
    model_construction_count = 0
    step_invocation_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physics_state_modified = $false
    supported_physics_subset_qualified = $false
    training_plane_authorized = $false
    scientific_result = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
$json = $receipt | ConvertTo-Json -Depth 12
if ($Output) {
    $outputPath = [IO.Path]::GetFullPath($Output)
    Assert-Mjw (-not (Test-Path -LiteralPath $outputPath)) "refusing to overwrite output"
    $parent = Split-Path -Parent $outputPath
    Assert-Mjw (Test-Path -LiteralPath $parent -PathType Container) "output parent missing"
    [IO.File]::WriteAllText($outputPath, $json + "`n", [Text.UTF8Encoding]::new($false))
}
Write-Output $json
Write-Host "MJWARP_SUBSET_PREFLIGHT_PASS runtime=$([bool]$RequireRuntime) models=0 steps=0 worlds=0 qualification=false training=false"
