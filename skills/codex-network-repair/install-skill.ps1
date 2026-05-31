param(
    [string]$Destination = "$env:USERPROFILE\.codex\skills\codex-network-repair"
)

$ErrorActionPreference = "Stop"
$source = Split-Path -Parent $MyInvocation.MyCommand.Path
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item -Path (Join-Path $source "*") -Destination $Destination -Recurse -Force
Write-Host "Installed codex-network-repair skill to $Destination"
