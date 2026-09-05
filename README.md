# wd for Windows

`wd` (warp directory) bookmarks directories you use often and lets you jump to them by name from PowerShell or Command Prompt.

```text
PS C:\projects\some-long-project-name> wd add project
PS C:\projects\some-long-project-name> cd C:\Windows
PS C:\Windows> wd project
PS C:\projects\some-long-project-name>
```

It follows the command model of the [`wd` plugin for Oh My Zsh](https://github.com/mfaerevaag/wd) by Markus Færevaag and understands Windows drive-letter paths. This is an independent Windows implementation, not an official Oh My Zsh project or an endorsed upstream release.

## License and attribution

The Windows implementation is available under the [MIT license](LICENSE).
The original plugin's copyright and MIT permission notice are preserved in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
MIT permits use, modification, redistribution, and commercial use subject to its notice requirements.

## Requirements

- Windows 10 or 11, x64
- [Git for Windows](https://git-scm.com/download/win)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) to build the executable during installation
- Windows PowerShell 5.1, PowerShell 7, or Command Prompt

The installed executable is self-contained, so the .NET runtime is not needed after it has been built.

## Install

For a prebuilt ZIP from this repository's GitHub Releases, extract it and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Install.ps1 -SkipBuild
```

This installation needs neither Git nor the .NET SDK. Keep the full archive
contents together, including the license notices.

To build from source, follow the instructions below.

Clone the repository and run the installer from PowerShell:

```powershell
git clone https://github.com/alexlvcom/wd.git
cd wd
powershell -ExecutionPolicy Bypass -File .\scripts\Install.ps1
```

You can also use **Code → Download ZIP**, extract it, and run the installer
from the extracted directory.

The installer:

- publishes a self-contained `wd-core.exe`;
- installs it with `wd.cmd` in `%USERPROFILE%\bin`;
- adds that directory to your user `PATH` if necessary;
- installs and enables the `wd` PowerShell function for Windows PowerShell 5.1 and PowerShell 7.

Close and reopen PowerShell or Command Prompt after installation. Verify it with:

```text
wd --version
```

To update later:

```powershell
cd path\to\wd
git pull
powershell -ExecutionPolicy Bypass -File .\scripts\Install.ps1
```

The installer is safe to run more than once. It updates the installed files without adding duplicate `PATH` or PowerShell profile entries.

## Usage

Save the current directory and jump back to it:

```text
wd add work
wd work
```

List, inspect, and remove saved points:

```text
wd list
wd show work
wd path work
wd rm work
```

Overwrite an existing point:

```text
wd add! work
wd add work --force
```

Save another directory without going there first:

```text
wd addcd C:\projects\my-app app
```

You can omit the point name from `wd add`, `wd add!`, or `wd rm` to use the current directory's name.

Other commands:

```text
wd work src          Jump to the src directory inside work
wd ls work           List files at the saved point
wd open work         Open it in File Explorer
wd clean             Remove points whose directories no longer exist
wd clean --force     Clean without confirmation
wd help              Show the complete command reference
```

## Configuration

Warp points are stored in:

```text
%USERPROFILE%\.warprc
```

Set `WD_CONFIG` to change that location for all commands, or use a different file for one command:

```text
wd --config C:\configs\work.warprc list
```

The file uses the original plugin's `name:path` convention. Windows drive paths
are not directly usable on Linux, and full compatibility with Zsh-escaped names
is not guaranteed:

```text
work:C:\projects\my-app
photos:D:\Pictures
```

## Why there is a shell wrapper

An executable cannot change the working directory of the shell that launched it. `wd-core.exe` handles the bookmark database and commands, while a tiny shell-specific entry point performs the final directory change:

- `wd.cmd` uses `cd /d` in Command Prompt;
- the PowerShell `wd` function uses `Set-Location`.

Both are installed under the same `wd` command and share the same bookmark file.

## Troubleshooting

If a newly installed `wd` is not found, close every open terminal and start a new one. You can inspect command discovery with:

```powershell
Get-Command wd -All
```

In PowerShell, the first result should be a function. In Command Prompt, this should find `%USERPROFILE%\bin\wd.cmd`:

```bat
where wd
```

For the current PowerShell session, without restarting it, run:

```powershell
Import-Module wd -Force
```

## Build and test

When sharing a self-contained build, include `LICENSE`, `THIRD-PARTY-NOTICES.md`,
and the `licenses/` directory from the publish output alongside the executable.
The installer keeps copies under `%USERPROFILE%\bin\wd-licenses`.
Do not distribute the executable alone.

```powershell
dotnet build .\src\Wd\Wd.csproj -c Release
dotnet publish .\src\Wd\Wd.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o .\publish
.\tests\Invoke-Tests.ps1 -Executable .\publish\wd-core.exe
```

## Project layout

Maintainers use the shared `dotnet-local-deploy` skill for local testing and
`dotnet-work-is-done` for GitHub releases from `master`. The repository-specific
release checklist is in [AGENTS.md](AGENTS.md). Run `scripts/Package.ps1` to build
`publish/wd-<version>-win-x64.zip` with the installer, wrappers, and license notices.

```text
src/Wd/Program.cs        Command implementation and .warprc storage
shell/wd.cmd             Command Prompt integration
shell/wd.psm1            PowerShell integration
scripts/Install.ps1      Build and per-user installation
tests/Invoke-Tests.ps1   PowerShell and CMD integration tests
```
