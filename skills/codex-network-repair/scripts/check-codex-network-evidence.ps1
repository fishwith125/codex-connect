param(
    [string]$CodexHome = "$env:USERPROFILE\.codex",
    [string]$ProxyPort = "7897"
)

$ErrorActionPreference = "Continue"

Write-Host "== Proxy registry =="
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" |
    Select-Object ProxyEnable,ProxyServer,AutoConfigURL |
    Format-List

Write-Host "== User proxy environment =="
$envProps = Get-ItemProperty "HKCU:\Environment"
$envProps.PSObject.Properties |
    Where-Object { $_.Name -match '^(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY)$' } |
    Select-Object Name,Value |
    Format-Table -AutoSize

Write-Host "== WinHTTP proxy =="
netsh winhttp show proxy

Write-Host "== Local proxy listener =="
netstat -ano | Select-String ":$ProxyPort"

Write-Host "== Codex process sockets =="
$codexPids = Get-Process | Where-Object { $_.ProcessName -match '^Codex$|^codex$' } | Select-Object -ExpandProperty Id
$lines = netstat -ano
foreach ($cpid in $codexPids) {
    $matches = $lines | Select-String "\s$cpid$"
    if ($matches) {
        "PID $cpid"
        $matches | Select-Object -First 80
    }
}

Write-Host "== Config features =="
$configPath = Join-Path $CodexHome "config.toml"
if (Test-Path -LiteralPath $configPath) {
    Get-Content -LiteralPath $configPath | Select-String -Pattern '^\[features\]|remote_' -Context 0,5
} else {
    Write-Warning "Missing config: $configPath"
}

Write-Host ""
Write-Host "Read the socket list carefully:"
Write-Host "- Codex -> 127.0.0.1:$ProxyPort means the proxy is being used."
Write-Host "- Codex -> external-ip:443 with SYN_SENT means direct bypass; enable TUN/transparent proxy."
