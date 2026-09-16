# wd for Windows — development

Requires the .NET 8 SDK.

## Build and test

```powershell
dotnet build .\src\Wd\Wd.csproj -c Release
dotnet publish .\src\Wd\Wd.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o .\publish
.\tests\Invoke-Tests.ps1 -Executable .\publish\wd-core.exe
```

The test script exercises both shells, since the PowerShell function and `wd.cmd` are separate integration points over the same executable.

## Packaging

`scripts/Package.ps1` builds `publish/wd-<version>-win-x64.zip` with the installer, the shell wrappers and the license notices.

When sharing a self-contained build, include `LICENSE`, `THIRD-PARTY-NOTICES.md` and the `licenses/` directory from the publish output alongside the executable. The installer keeps copies under `%USERPROFILE%\bin\wd-licenses`. **Do not distribute the executable alone** — the third-party MIT notice must travel with it.

## Project layout

```text
src/Wd/Program.cs        Command implementation and .warprc storage
shell/wd.cmd             Command Prompt integration
shell/wd.psm1            PowerShell integration
scripts/Install.ps1      Build and per-user installation
scripts/Package.ps1      Release ZIP
tests/Invoke-Tests.ps1   PowerShell and CMD integration tests
```

## Release process

The repository-specific release checklist is in [AGENTS.md](../AGENTS.md). Releases are cut from `master`.
