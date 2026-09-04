function wd {
    $core = Get-Command wd-core.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $targetFile = Join-Path ([IO.Path]::GetTempPath()) ("wd-{0}.tmp" -f [Guid]::NewGuid().ToString('N'))
    $previousTargetFile = [Environment]::GetEnvironmentVariable('WD_SHELL_TARGET_FILE', 'Process')

    try {
        [Environment]::SetEnvironmentVariable('WD_SHELL_TARGET_FILE', $targetFile, 'Process')
        & $core.Source @args
        $coreExitCode = $LASTEXITCODE

        if ($coreExitCode -eq 0 -and (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
            $target = [IO.File]::ReadAllText($targetFile)
            if (-not [string]::IsNullOrWhiteSpace($target)) {
                Set-Location -LiteralPath $target
            }
        }
    }
    finally {
        [Environment]::SetEnvironmentVariable('WD_SHELL_TARGET_FILE', $previousTargetFile, 'Process')
        Remove-Item -LiteralPath $targetFile -Force -ErrorAction SilentlyContinue
        if ($null -ne $coreExitCode) {
            $global:LASTEXITCODE = $coreExitCode
        }
    }
}

Export-ModuleMember -Function wd
