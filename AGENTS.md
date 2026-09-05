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
- After a user-visible change, run a Release build, publish the exact self-contained executable, run `tests/Invoke-Tests.ps1`, and deploy it using the private `.ai-metadata.env` target for local testing.
- Do not commit `.ai-metadata.env`, `bin/`, `obj/`, `publish/`, or test artifacts.
- Do not commit, tag, push, or publish a hosted release unless the user explicitly asks for those actions.

## Deployment and GitHub releases

- Use the shared `dotnet-local-deploy` skill after implementation. Resolve the executable destination from private `.ai-metadata.env`; install updated wrappers and license notices too.
- When the user says "work is done", use `dotnet-work-is-done` and `commit-message-style`. The release branch is `master`; GitHub origin is `https://github.com/alexlvcom/wd.git`.
- Preflight authenticated GitHub release access before committing or tagging a release. Git push access alone does not prove release API access.
- Finalize README and CHANGELOG, verify matching versions, run the Release build and shell tests, commit, and rebuild from that commit.
- Run `scripts/Package.ps1` from the exact release commit. Test the archive's installer with `-SkipBuild`; users must not need an SDK for a downloaded release.
- Push `master`, create and push an annotated `v<version>` tag, and publish a normal GitHub release with changelog notes.
- Upload `wd-<version>-win-x64.zip`, which includes the executable, wrappers, installer, and license notices. This complete archive is the release asset instead of a bare executable.
- Verify the remote branch/tag, download the uploaded archive, and compare its SHA-256 with the local archive. Include its hash in the release notes.
