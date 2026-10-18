# switch-module-source.ps1
# Toggles module sources in main.tf between local (../) and CI (./) paths
#
# Usage:
#   .\switch-module-source.ps1 -mode local    # For running terraform locally
#   .\switch-module-source.ps1 -mode ci       # Before pushing / for GitHub Actions

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("local", "ci")]
    [string]$mode
)

$mainTf = Join-Path $PSScriptRoot "main.tf"

if (-not (Test-Path $mainTf)) {
    Write-Error "main.tf not found at: $mainTf"
    exit 1
}

$content = Get-Content $mainTf -Raw

if ($mode -eq "local") {
    $updated = $content -replace 'source\s*=\s*"\./terraform-azure-lz-modules/', 'source = "../terraform-azure-lz-modules/'
    $description = "./  -->  ../"
} else {
    $updated = $content -replace 'source\s*=\s*"\.\./terraform-azure-lz-modules/', 'source = "./terraform-azure-lz-modules/'
    $description = "../  -->  ./"
}

if ($updated -eq $content) {
    Write-Host "No changes needed — sources are already set for mode: $mode"
} else {
    Set-Content $mainTf $updated -NoNewline
    Write-Host "Switched module sources ($description) for mode: $mode"
}
