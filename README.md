# codex-connect

Reusable Codex connectivity repair guidance and scripts.

This repository currently contains a Codex skill for diagnosing and repairing Codex Desktop / CLI connectivity issues on Windows, especially when mobile remote control appears offline while normal Codex chat still works.

## Included Skill

- `skills/codex-network-repair`

Use it when:

- Codex cannot connect behind Clash, mihomo, VPN, or a local proxy.
- Codex normal requests work but mobile remote control still shows offline.
- WebSocket checks fail or remote-control logs show repeated 30 second timeouts.
- A Codex process bypasses the proxy and directly opens external `:443` sockets.

## Install Locally

From this repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\codex-network-repair\install-skill.ps1
```

## Repair Codex Networking

Run from an elevated PowerShell when possible:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\skills\codex-network-repair\scripts\repair-codex-network.ps1 -ProxyUrl http://127.0.0.1:7897
```

Then fully quit and reopen Codex Desktop.

If Codex still shows direct external `SYN_SENT :443` sockets, enable Clash Verge Service Mode plus TUN/Enhanced Mode so transparent proxying covers processes that ignore environment variables.

