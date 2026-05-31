---
name: codex-network-repair
description: Use when Codex Desktop or CLI cannot connect, mobile remote control cannot see the desktop online, WebSocket checks fail, or Codex works for normal chat but remote control keeps timing out behind Clash, mihomo, VPN, or a local proxy on Windows.
---

# Codex Network Repair

## Core Rule

Diagnose by evidence before changing settings. Codex has several network paths:

- normal ChatGPT/Codex API requests
- Responses WebSocket
- desktop app-server remote-control WebSocket
- Windows system / WinHTTP / transparent proxy paths

Do not assume that fixing one path fixes the others.

## Quick Workflow

1. Confirm the proxy endpoint:
   - Find the local proxy port, commonly `127.0.0.1:7897` for Clash Verge/mihomo.
   - Verify it is listening.
2. Check Codex configuration:
   - `remote_control = true`
   - `remote_connections = true`
3. Set all proxy layers:
   - user env: uppercase and lowercase `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY`
   - Windows user system proxy: `HKCU\...\Internet Settings`
   - WinHTTP proxy when running elevated
4. Restart Codex Desktop fully after proxy/config changes.
5. Read evidence from logs and netstat:
   - Success: app-server remote control should stop logging 30s timeouts.
   - Failure pattern: normal Codex requests log proxy use, but `remote_control::websocket` still times out.
   - Strong root cause: a `codex.exe` process has direct `SYN_SENT` to external `:443` instead of `127.0.0.1:<proxyPort>`.
6. If direct SYN persists, use transparent routing:
   - Enable Clash Verge Service Mode plus TUN/Enhanced Mode.
   - Use Global mode or add rules for `chatgpt.com`, `*.openai.com`, and remote-control WebSocket traffic.

## Windows Repair Script

Run `scripts/repair-codex-network.ps1` from this skill. Prefer an elevated PowerShell window so WinHTTP can be updated too:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\repair-codex-network.ps1 -ProxyUrl http://127.0.0.1:7897
```

When not elevated, the script still updates user config, user proxy env, and Windows user system proxy. It prints whether WinHTTP was skipped or denied.

## Evidence Commands

Find Codex remote-control logs:

```powershell
@'
import sqlite3
p=__import__('os').path.expandvars(r'%USERPROFILE%\.codex\logs_2.sqlite')
con=sqlite3.connect(p)
rows=con.execute("""
select id, ts, level, target, feedback_log_body
from logs
where target like '%remote_control%'
   or feedback_log_body like '%remote control websocket%'
   or feedback_log_body like '%wham/remote/control%'
order by id desc limit 40
""")
for row in rows:
    print("\n---", row[0], row[1], row[2], row[3])
    print((row[4] or '')[:1200])
con.close()
'@ | python -
```

Check whether Codex is bypassing the proxy:

```powershell
$codexPids = Get-Process | Where-Object { $_.ProcessName -match '^Codex$|^codex$' } | Select-Object -ExpandProperty Id
$lines = netstat -ano
foreach ($cpid in $codexPids) {
  $matches = $lines | Select-String "\s$cpid$"
  if ($matches) {
    "PID $cpid"
    $matches | Select-Object -First 60
  }
}
```

If remote control is stuck and a Codex process shows direct external `SYN_SENT` on port `443`, environment variables are not enough. Use TUN/transparent proxy or elevated WinHTTP/system routing.

## Interpretation

- `remoteControl/status/changed` only means the app-server emitted status, not that the cloud WebSocket is connected.
- `initial_enabled=false` at startup can be followed by runtime enablement; do not stop there if later logs show connection attempts.
- `has_enrollment=true` means the desktop is paired/enrolled. If connection still times out, treat it as network routing.
- `doctor websocket connected (HTTP 101)` proves the Responses WebSocket path, not necessarily the remote-control WebSocket path.
- `remote_control` may appear as removed in some `features list` output, but current app-server builds can still reference it internally. Keep both `remote_control` and `remote_connections` in config when repairing this specific issue.

## Common Fix Matrix

| Symptom | Likely Cause | Next Action |
| --- | --- | --- |
| Normal Codex requests fail | Proxy not configured or auth broken | Set proxy env/system proxy, run doctor |
| Doctor WebSocket fails | Proxy blocks WebSockets | Switch node/rule, test another proxy mode |
| Normal requests work, mobile remote says offline | Remote-control WebSocket not connected | Inspect `remote_control::websocket` logs |
| Remote-control logs 30s timeout | Remote-control path bypassing proxy or blocked | Enable TUN/Service Mode or WinHTTP |
| Codex process shows external `SYN_SENT :443` | Direct connection bypass | Transparent proxy required |
| Config write denied from Codex tools | Sandbox user has read-only `.codex` ACL | Run repair script from normal/elevated PowerShell |
