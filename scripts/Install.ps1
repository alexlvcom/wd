[CmdletBinding()]
param(
    [string] $PublishDirectory = (Join-Path $PSScriptRoot '..\publish'),
    [string] $BinDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'bin')
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectFile = Join-Path $projectRoot 'src\Wd\Wd.csproj'
$publishDirectory = [IO.Path]::GetFullPath($PublishDirectory)
$binDirectory = [IO.Path]::GetFullPath($BinDirectory)

dotnet publish $projectFile -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o $publishDirectory
if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed.' }

New-Item -ItemType Directory -Path $binDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $publishDirectory 'wd-core.exe') -Destination (Join-Path $binDirectory 'wd-core.exe') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'shell\wd.cmd') -Destination (Join-Path $binDirectory 'wd.cmd') -Force

[string] $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$binIsOnPath = $pathEntries | Where-Object {
    $expandedEntry = [Environment]::ExpandEnvironmentVariables($_.Trim().Trim('"')).TrimEnd('\')
    [string]::Equals($expandedEntry, $binDirectory.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)
}
if (-not $binIsOnPath) {
    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        $binDirectory
    }
    else {
        "$($userPath.TrimEnd(';'));$binDirectory"
    }
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    Write-Host "Added $binDirectory to the user PATH."
}

$powerShellRoots = @(
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell')
) | Select-Object -Unique

foreach ($powerShellRoot in $powerShellRoots) {
    $moduleRoot = Join-Path $powerShellRoot 'Modules\wd'
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'shell\wd.psm1') -Destination (Join-Path $moduleRoot 'wd.psm1') -Force

    $profilePath = Join-Path $powerShellRoot 'profile.ps1'
    if (-not (Test-Path -LiteralPath $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    $profileLines = @(Get-Content -LiteralPath $profilePath -ErrorAction SilentlyContinue)
    if ($profileLines -notcontains '# wd for Windows') {
        if ($profileLines.Count -gt 0) {
            Add-Content -LiteralPath $profilePath -Value ''
        }
        Add-Content -LiteralPath $profilePath -Value '# wd for Windows'
        Add-Content -LiteralPath $profilePath -Value 'Import-Module wd'
    }
}

Write-Host "Installed wd-core.exe and wd.cmd in $binDirectory"
Write-Host 'Installed and enabled the wd module for Windows PowerShell and PowerShell.'
Write-Host 'Open a new shell, then run: wd --version'
