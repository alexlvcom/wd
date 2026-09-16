# wd for Windows — user guide

- [Requirements](#requirements)
- [Installing](#installing)
- [Usage](#usage)
- [The bookmark file](#the-bookmark-file)
- [Why there is a shell wrapper](#why-there-is-a-shell-wrapper)
- [Troubleshooting](#troubleshooting)

## Requirements

- Windows 10 or 11, x64
- Windows PowerShell 5.1, PowerShell 7, or Command Prompt

Installing from source additionally needs [Git for Windows](https://git-scm.com/download/win) and the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) to build the executable. The installed executable is self-contained, so the .NET runtime is not needed afterwards.

## Installing

### From a release ZIP

Download the archive from the [releases page](https://github.com/alexlvcom/wd/releases/latest), extract it, and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Install.ps1 -SkipBuild
```

This needs neither Git nor the .NET SDK. Keep the full archive contents together, including the license notices.

### From source

```powershell
git clone https://github.com/alexlvcom/wd.git
cd wd
powershell -ExecutionPolicy Bypass -File .\scripts\Install.ps1
```

You can also use **Code → Download ZIP**, extract it, and run the installer from the extracted directory.

### What the installer does

- publishes a self-contained `wd-core.exe`;
- installs it with `wd.cmd` in `%USERPROFILE%\bin`;
- adds that directory to your user `PATH` if necessary;
- installs and enables the `wd` PowerShell function for Windows PowerShell 5.1 and PowerShell 7.

Close and reopen PowerShell or Command Prompt afterwards. Verify it with:

```text
wd --version
```

### Updating

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

## The bookmark file

Warp points are stored in:

```text
%USERPROFILE%\.warprc
```

Set `WD_CONFIG` to change that location for all commands, or use a different file for one command:

```text
wd --config C:\configs\work.warprc list
```

The file uses the original plugin's `name:path` convention. Windows drive paths are not directly usable on Linux, and full compatibility with Zsh-escaped names is not guaranteed:

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
