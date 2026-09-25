<#
.SYNOPSIS
  Sets up a Windows machine (x64 or Arm64) to build and run this repo: .NET 11 SDK, MAUI workloads, maui CLI, labs templates.

.DESCRIPTION
  Run from an *elevated* PowerShell 7 prompt (the SDK and workloads install under C:\Program Files\dotnet):

      pwsh -ExecutionPolicy Bypass -File eng\setup-windows.ps1

  Steps:
    1. Installs the exact .NET SDK pinned in global.json for this machine's architecture (official installer, silent).
    2. Installs the MAUI workloads for that SDK band ("maui" = android + ios + maccatalyst + maui-windows).
       Use -WindowsOnly to install just maui-windows (enough for the WPF head and the default app's Windows target).
    3. Installs/updates the maui CLI (DevFlow) global tool and the labs project templates.
#>
[CmdletBinding()]
param(
  [switch] $WindowsOnly,
  [switch] $SkipSdk
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$sdkVersion = (Get-Content (Join-Path $repoRoot 'global.json') | ConvertFrom-Json).sdk.version
$arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'x64' }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this script from an elevated (Administrator) PowerShell so the SDK and workloads install under C:\Program Files\dotnet.' }

if (-not $SkipSdk) {
  $installed = (& dotnet --list-sdks 2>$null) -match [regex]::Escape($sdkVersion)
  if ($installed) {
    Write-Host "==> .NET SDK $sdkVersion already installed"
  } else {
    $url = "https://builds.dotnet.microsoft.com/dotnet/Sdk/$sdkVersion/dotnet-sdk-$sdkVersion-win-$arch.exe"
    $installer = Join-Path $env:TEMP "dotnet-sdk-$sdkVersion-win-$arch.exe"
    Write-Host "==> Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $installer
    Write-Host "==> Installing .NET SDK $sdkVersion ($arch) silently"
    $proc = Start-Process -FilePath $installer -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
    if ($proc.ExitCode -notin 0, 3010) { throw "SDK installer exited with $($proc.ExitCode)" }
  }
}

Push-Location $repoRoot
try {
  Write-Host "==> dotnet $(dotnet --version) (resolved via global.json)"
  $workload = if ($WindowsOnly) { 'maui-windows' } else { 'maui' }
  Write-Host "==> Installing workload '$workload'"
  dotnet workload install $workload

  Write-Host "==> Installing/updating the maui CLI (includes DevFlow)"
  dotnet tool update -g Microsoft.Maui.Cli --prerelease

  Write-Host "==> Installing the dotnet/maui-labs project templates (WPF + GTK4; no macOS template package is published)"
  $labsVersion = ([xml](Get-Content (Join-Path $repoRoot 'Directory.Build.props'))).Project.PropertyGroup.MauiLabsVersion
  dotnet new install "Microsoft.Maui.Platforms.Windows.WPF.Templates::$labsVersion"
  dotnet new install "Microsoft.Maui.Platforms.Linux.Gtk4.Templates::$labsVersion"

  Write-Host "==> maui doctor"
  maui doctor
}
finally { Pop-Location }

Write-Host ''
Write-Host 'Done. Try:'
Write-Host '  dotnet run --project src\MauiPlatforms.Wpf'
Write-Host '  dotnet build src\MauiPlatforms -f net11.0-windows10.0.19041.0'
