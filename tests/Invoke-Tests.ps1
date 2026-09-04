[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Executable,

    [string] $CmdWrapper = (Join-Path $PSScriptRoot '..\shell\wd.cmd'),
    [string] $PowerShellModule = (Join-Path $PSScriptRoot '..\shell\wd.psm1'),

    [switch] $VerifyPowerShellProfile
)

$ErrorActionPreference = 'Stop'
$Executable = [IO.Path]::GetFullPath($Executable)
$CmdWrapper = [IO.Path]::GetFullPath($CmdWrapper)
$PowerShellModule = [IO.Path]::GetFullPath($PowerShellModule)
$originalLocation = (Get-Location).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("wd-tests-{0}" -f [Guid]::NewGuid().ToString('N'))
$first = Join-Path $testRoot 'First Place'
$second = Join-Path $testRoot 'Second & Place'
$child = Join-Path $first 'child'
$config = Join-Path $testRoot '.warprc'
$testBin = Join-Path $testRoot 'bin'

function Assert-Equal($Expected, $Actual, [string] $Message) {
    if ($Expected -ne $Actual) {
        throw "$Message`nExpected: $Expected`nActual:   $Actual"
    }
}

try {
    New-Item -ItemType Directory -Path $first, $second, $child, $testBin -Force | Out-Null
    Copy-Item -LiteralPath $CmdWrapper -Destination (Join-Path $testBin 'wd.cmd')
    $oldPath = $env:PATH
    $oldConfig = $env:WD_CONFIG
    $env:PATH = "$testBin;$(Split-Path -Parent $Executable);$env:PATH"
    $env:WD_CONFIG = $config

    Push-Location $first
    try {
        & $Executable add alpha --quiet
        Assert-Equal 0 $LASTEXITCODE 'add should succeed'
    }
    finally { Pop-Location }

    $listed = & $Executable list
    if ($listed -notmatch 'alpha\s+->\s+.+First Place') { throw 'list did not include alpha.' }

    Push-Location $second
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable add alpha --quiet 2>$null
        $duplicateExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        Assert-Equal 1 $duplicateExit 'duplicate add should fail'
        & $Executable add! alpha --quiet
        Assert-Equal 0 $LASTEXITCODE 'add! should overwrite'
    }
    finally { Pop-Location }
    Assert-Equal $second (& $Executable path alpha) 'path should show overwritten target'

    & $Executable addcd $first original --quiet
    Assert-Equal $first (& $Executable path original) 'addcd should store an arbitrary directory'

    Import-Module $PowerShellModule -Force
    Set-Location $second
    wd original child
    Assert-Equal $child (Get-Location).Path 'PowerShell wrapper should change location with a subdirectory'
    wd add original --force --quiet
    Assert-Equal $child (& $Executable path original) 'PowerShell wrapper should forward option-like arguments'
    & $Executable addcd $first original --force --quiet

    $cmdOutput = @(& cmd.exe /d /c "set WD_CONFIG=$config&&cd /d `"$second`"&&call `"$testBin\wd.cmd`" original&&cd")
    Assert-Equal $first $cmdOutput[-1] 'cmd wrapper should change its caller location'
    $cmdSpecialOutput = @(& cmd.exe /d /c "set WD_CONFIG=$config&&cd /d `"$first`"&&call `"$testBin\wd.cmd`" alpha&&cd")
    Assert-Equal $second $cmdSpecialOutput[-1] 'cmd wrapper should handle metacharacters in target paths'

    if ($VerifyPowerShellProfile) {
        $freshProcessScript = @"
Set-Location -LiteralPath '$second'
wd original
Write-Output ((Get-Command wd).CommandType)
Write-Output ((Get-Location).Path)
"@
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($freshProcessScript))
        $freshOutput = @(& powershell.exe -NoLogo -EncodedCommand $encodedCommand)
        Assert-Equal 'Function' $freshOutput[-2] 'A fresh PowerShell should discover wd as a function'
        Assert-Equal $first $freshOutput[-1] 'A fresh PowerShell wd call should retain its new location'
    }

    & $Executable rm alpha --quiet
    Assert-Equal 0 $LASTEXITCODE 'rm should succeed'
    $ErrorActionPreference = 'Continue'
    & $Executable path alpha 2>$null
    $removedExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Assert-Equal 1 $removedExit 'removed point should be unknown'

    $ErrorActionPreference = 'Continue'
    & $Executable addcd (Join-Path $testRoot 'missing') dead --quiet 2>$null
    $missingExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Assert-Equal 1 $missingExit 'addcd should reject missing directories'
    [IO.File]::AppendAllText($config, "dead:$testRoot\missing$([Environment]::NewLine)")
    & $Executable clean --force --quiet
    Assert-Equal 0 $LASTEXITCODE 'clean should succeed'
    if ((Get-Content -Raw $config) -match '(?m)^dead:') { throw 'clean did not remove dead point.' }

    Write-Host 'All wd tests passed.'
}
finally {
    $env:PATH = $oldPath
    $env:WD_CONFIG = $oldConfig
    Set-Location -LiteralPath $originalLocation
    Remove-Module wd -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
