param(
    [string]$CodexHome = "$env:USERPROFILE\.codex",
    [string]$ProxyUrl = "http://127.0.0.1:7897",
    [string]$NoProxy = "localhost,127.0.0.1,::1",
    [switch]$SkipWinHttp
)

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-TomlFeature {
    param(
        [string]$Text,
        [string]$Name,
        [string]$Value
    )

    if ($Text -notmatch '(?m)^\[features\]\s*$') {
        return ($Text.TrimEnd() + "`r`n`r`n[features]`r`n$Name = $Value`r`n")
    }

    if ($Text -match "(?m)^$([regex]::Escape($Name))\s*=") {
        return ($Text -replace "(?m)^$([regex]::Escape($Name))\s*=.*$", "$Name = $Value")
    }

    return ($Text -replace '(?m)^(\[features\]\s*\r?\n)', "`${1}$Name = $Value`r`n")
}

$configPath = Join-Path $CodexHome "config.toml"
if (!(Test-Path -LiteralPath $configPath)) {
    throw "Codex config not found: $configPath"
}

$backupPath = "$configPath.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $configPath -Destination $backupPath -Force

$content = Get-Content -LiteralPath $configPath -Raw
$content = Set-TomlFeature -Text $content -Name "remote_control" -Value "true"
$content = Set-TomlFeature -Text $content -Name "remote_connections" -Value "true"
Set-Content -LiteralPath $configPath -Value $content -Encoding UTF8

$proxyNames = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")
foreach ($name in $proxyNames) {
    [Environment]::SetEnvironmentVariable($name, $ProxyUrl, "User")
}
[Environment]::SetEnvironmentVariable("NO_PROXY", $NoProxy, "User")
[Environment]::SetEnvironmentVariable("no_proxy", $NoProxy, "User")

$proxyUri = [Uri]$ProxyUrl
$proxyHostPort = if ($proxyUri.IsDefaultPort) { $proxyUri.Host } else { "$($proxyUri.Host):$($proxyUri.Port)" }
$internetSettings = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set-ItemProperty -Path $internetSettings -Name ProxyEnable -Type DWord -Value 1
Set-ItemProperty -Path $internetSettings -Name ProxyServer -Type String -Value $proxyHostPort
Remove-ItemProperty -Path $internetSettings -Name AutoConfigURL -ErrorAction SilentlyContinue

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
$result = [UIntPtr]::Zero
[NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 0x0002, 5000, [ref]$result) | Out-Null

$admin = Test-IsAdmin
if (!$SkipWinHttp) {
    if ($admin) {
        & netsh winhttp set proxy $proxyHostPort $NoProxy | Out-Host
    } else {
        Write-Warning "WinHTTP proxy was not changed because this PowerShell session is not elevated."
    }
}

Write-Host ""
Write-Host "Codex network repair applied."
Write-Host "Config backup: $backupPath"
Write-Host "Proxy: $ProxyUrl"
Write-Host "Windows user system proxy: enabled at $proxyHostPort"
Write-Host "WinHTTP attempted: $(!$SkipWinHttp -and $admin)"
Write-Host ""
Write-Host "Next: fully quit Codex Desktop, reopen it, then test mobile remote control."
Write-Host "If Codex still shows direct external SYN_SENT :443, enable Clash Verge Service Mode + TUN/Enhanced Mode."
