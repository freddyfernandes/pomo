# Builds Pomo.exe from Pomo.cs with the C# compiler that ships with Windows (no installs needed).
#   powershell -ExecutionPolicy Bypass -File build.ps1
# Produces .\Pomo.exe next to this script. Requires Windows 10/11 and the .NET Framework 4.x.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
if (-not (Test-Path $csc)) { throw "csc.exe not found: enable .NET Framework 4.x or use Visual Studio Build Tools" }

& $csc /nologo /optimize+ /target:winexe /out:Pomo.exe /r:System.Windows.Forms.dll /r:System.Drawing.dll Pomo.cs
if ($LASTEXITCODE -ne 0) { throw "build failed" }
Write-Host "Built $PSScriptRoot\Pomo.exe"
if ($args -notcontains "--no-run") { Start-Process (Join-Path $PSScriptRoot "Pomo.exe") }
