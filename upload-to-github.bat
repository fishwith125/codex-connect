@echo off
setlocal
if "%GITHUB_TOKEN%"=="" (
  echo Please set GITHUB_TOKEN first.
  echo Example:
  echo   set GITHUB_TOKEN=ghp_your_token_here
  exit /b 1
)
if "%~1"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\publish-to-github.ps1" -Token "%GITHUB_TOKEN%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\publish-to-github.ps1" -Token "%GITHUB_TOKEN%" -RepoUrl "%~1"
)
