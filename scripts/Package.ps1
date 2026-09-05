# Builds a release archive without changing the local installation.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'src/Wd/Wd.csproj'
[xml] $metadata = Get-Content -Raw -LiteralPath $project
$version = $metadata.Project.PropertyGroup.Version
$stage = Join-Path $root ('publish/package-' + [Guid]::NewGuid().ToString('N'))
$output = Join-Path $stage 'publish'
dotnet publish $project -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:DebugType=None -p:DebugSymbols=false -o $output
if ($LASTEXITCODE -ne 0) { throw 'Publish failed.' }
foreach ($folder in @('scripts', 'shell')) {
    New-Item -ItemType Directory -Path (Join-Path $stage $folder) -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install.ps1') -Destination (Join-Path $stage 'scripts')
Copy-Item -LiteralPath (Join-Path $root 'shell/wd.cmd'), (Join-Path $root 'shell/wd.psm1') -Destination (Join-Path $stage 'shell')
Copy-Item -LiteralPath (Join-Path $root 'README.md'), (Join-Path $root 'LICENSE'), (Join-Path $root 'THIRD-PARTY-NOTICES.md'), (Join-Path $root 'CHANGELOG.md') -Destination $stage
$archive = Join-Path $root "publish/wd-$version-win-x64.zip"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive -Force
Get-FileHash -LiteralPath $archive -Algorithm SHA256
