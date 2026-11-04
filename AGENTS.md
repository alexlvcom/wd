# Repository Instructions

- This is a Windows x64 .NET 8 command-line application. Keep it working in Windows PowerShell 5.1, PowerShell 7, and `cmd.exe`.
- Read `README.md` and `CHANGELOG.md` before making user-visible changes.
- Keep the public command behavior close to the upstream Oh My Zsh `wd` plugin unless a Windows limitation requires a documented difference.
- Preserve compatibility with the plain-text `%USERPROFILE%\.warprc` format. Split each mapping on its first colon so Windows drive-letter paths remain intact.
- A child executable cannot change its parent shell's directory. Navigation changes must continue to use `wd-core.exe` plus `shell/wd.cmd` and the PowerShell `wd` function.
- Treat paths as untrusted input. Test spaces, ampersands, drive-letter colons, missing directories, optional subdirectories, and argument forwarding through both wrappers.
- Keep installation idempotent. Never duplicate user `PATH` entries or managed PowerShell profile lines, and preserve unrelated profile content.
- Keep version values in `src/Wd/Wd.csproj` synchronized: `Version` and `InformationalVersion` use `N.N.N`; `FileVersion` and `AssemblyVersion` use `N.N.N.0`.
- Do not append commit hashes or other build identifiers to the product version.
- Preserve LICENSE and THIRD-PARTY-NOTICES.md. Distribute them and the published licenses directory with binaries; retain the notices from the exact bundled .NET runtime.
- Use one changelog heading for all work planned for the same unreleased version. Do not bump the version again during testing iterations.
- After a user-visible change, run a Release build, publish the exact self-contained executable, run `tests/Invoke-Tests.ps1`, and install it with `scripts/Install.ps1` (default destination `%USERPROFILE%\bin`) for local testing.
- Do not commit `.ai-metadata.env`, `bin/`, `obj/`, `publish/`, or test artifacts.
- Do not commit, tag, push, or publish a hosted release unless the user explicitly asks for those actions.

## Deployment and GitHub releases

- Use the shared `dotnet-local-deploy` skill after implementation. Install with `scripts/Install.ps1` into its default `%USERPROFILE%\bin`; it installs the wrappers and license notices too.
- When the user says "work is done", use `dotnet-work-is-done` and `commit-message-style`. The release branch is `master`; GitHub origin is `https://github.com/alexlvcom/wd.git`.
- Preflight authenticated GitHub release access before committing or tagging a release. Git push access alone does not prove release API access.
- Finalize README and CHANGELOG, verify matching versions, run the Release build and shell tests, commit, and rebuild from that commit.
- Run `scripts/Package.ps1` from the exact release commit. Test the archive's installer with `-SkipBuild`; users must not need an SDK for a downloaded release.
- Push `master`, create and push an annotated `v<version>` tag, and publish a normal GitHub release with changelog notes.
- Upload `wd-<version>-win-x64.zip`, which includes the executable, wrappers, installer, and license notices. This complete archive is the release asset instead of a bare executable.
- Verify the remote branch/tag, download the uploaded archive, and compare its SHA-256 with the local archive. Include its hash in the release notes.

## Third-Party Accounts And Setups

When adding, changing, or removing a third-party service, integration, account, project, billing arrangement, or provider setup for this project, update the private AlexLV app directory in the same task. Update the relevant app entry's `details.third_party` in `public/apps.json` and the matching section in `public/docs/third-party-accounts.md`. For a project without an app card, update the inventory document without adding a card unless requested. Include the provider, purpose, environment, project or account identity, and relevant billing details when known. Remove or correct obsolete details and distinguish confirmed facts from information that could not be verified. Never put passwords, API keys, tokens, private keys, or other secrets in the directory, Git, or logs.

The directory checkout is `~/sites/alexlv.com` on the home PC or `~/source/alexlvcom` on the work laptop. Follow its `AGENTS.md`, deploy changes to the configured DEV site, and verify the updated protected page and document before reporting the task complete. Include the directory repository in the session's final Git sweep.
