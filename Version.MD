# Version Release Workflow

This file describes the release flow agents must follow when the user asks to release a new `MavenCentralPublisher.ps1` version.

These instructions apply only to the `JvmMavenCentralPublisherPs` repository itself. They are not instructions for consuming repositories that install this repository as a tool.

## Version Source

The script version is stored in `MavenCentralPublisher.ps1`:

```powershell
$ScriptVersion = "1.0.0"
```

The version command must return this value:

```powershell
.\MavenCentralPublisher.ps1 -Version
```

Expected output shape:

```text
1.0.0
```

## Decide The Next Version

When the user asks to release a new version, inspect the history since the latest tag:

```powershell
git tag --sort=-creatordate
git log --oneline <last-tag>..HEAD
```

If there is no previous tag, inspect the relevant repository history:

```powershell
git log --oneline
```

Choose the next version using SemVer:

- `MAJOR`: incompatible command behavior, output contract breaks, renamed or removed flags, incompatible secret names, incompatible Gradle property names, incompatible file layout changes, destructive behavior changes, or migration requirements.
- `MINOR`: new commands, new parameters, new supported publishing workflows, new reusable Gradle publishing behavior, or meaningful backward-compatible feature additions.
- `PATCH`: bug fixes, documentation corrections, tests, help text updates, release guide fixes, or internal refactors that do not change public behavior.

If the right bump is ambiguous, explain the options and recommend one before proceeding.

## Prepare The Release

Before committing a release:

- Check `git status --short` and identify unrelated user changes.
- Do not revert unrelated changes.
- Do not clear, reset, overwrite, stage, or commit local secrets.
- Validate that tracked files do not contain real Sonatype credentials, signing keys, signing passwords, or other secret values.
- Update `$ScriptVersion` in `MavenCentralPublisher.ps1`.
- Update `README.md` command documentation and current version references.
- Keep the `README.md` section that explains how to install this tool in a consumer project with `ToolsManagerPs`.
- Update `CHANGELOG.md` by moving `Unreleased` changes into a versioned section.
- Update `Version.MD` if the release workflow changed.
- Run PowerShell parser validation for `MavenCentralPublisher.ps1`.
- Run relevant smoke checks for commands that do not modify secrets or publish artifacts.

Secrets are machine-local values managed by `DevSecretsManagerPs`. They are not release artifacts, they are not part of the Git working tree, and they can vary per developer or build machine.

## Documentation Requirements

For every release:

- `README.md` must show valid commands.
- `README.md` must document command flags, required parameters, behavior, and safety rules.
- `README.md` must keep the consumer-project installation flow that uses `ToolsManagerPs`.
- `README.md` must show the current version if it references a version.
- `CHANGELOG.md` must contain a section for the released version using the repository format `## X.Y.Z`, without a date suffix.
- `Version.MD` must remain repository-local and must describe the current release workflow.

Keep the README as the source of truth for tool usage, installation, and available commands.

## Validate Before Commit

Validate the PowerShell script before staging:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\MavenCentralPublisher.ps1), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { $_.Message }
    exit 1
}
```

Confirm the script returns the expected version:

```powershell
.\MavenCentralPublisher.ps1 -Version
```

Confirm usage/help still renders:

```powershell
.\MavenCentralPublisher.ps1
.\MavenCentralPublisher.ps1 -Help
```

Do not run `-List`, `-Set`, `-Edit`, `-UploadSigningPublicKey`, or `-Publish` as part of a normal release validation unless the release explicitly requires reading or changing local secrets, uploading a real public key, or performing a real Maven Central publication.

If list-related behavior changed, validate `-List` only in a controlled environment with dummy secrets.

## Conventional Commits

Create commits using Conventional Commits. Use a short subject and a detailed body when the change needs context for future changelog generation.

Example:

```powershell
git commit -m "docs: update release guide" -m "Update the internal release guide for JvmMavenCentralPublisherPs with the current validation, documentation, staging, tagging, and push workflow. This change does not alter script behavior."
```

Use commit types according to the release impact:

- `feat` for backward-compatible features.
- `fix` or `perf` for patch-level runtime changes.
- `docs` for documentation-only changes.
- `test` for test-only changes.
- `chore`, `refactor`, `style`, `build`, or `ci` for maintenance changes that do not affect runtime behavior.
- Add `!` or `BREAKING CHANGE:` only for breaking changes.

Do not include personal data, secrets, credentials, tokens, certificates, private URLs, or connection strings in commit messages.

Use one or more technical conventional commits before the final release commit. Stage only the files that belong to each commit.

Examples for the current repository:

```powershell
git status --short
git commit -m "fix(publisher): repair text file reads"
git commit -m "docs(readme): document ToolsManagerPs installation"
git commit -m "docs(release): align release workflow with ToolsManagerPs"
```

Commit messages must be detailed enough to understand what changed from the Git history.

## Final Release Commit

After feature, fix, test, and documentation commits are complete, create one final release commit:

```text
chore(release): bump JvmMavenCentralPublisherPs to X.Y.Z
```

Before this commit:

- Ensure `MavenCentralPublisher.ps1` has `$ScriptVersion = "X.Y.Z"`.
- Ensure `README.md` references `X.Y.Z` where relevant.
- Ensure `CHANGELOG.md` has `## X.Y.Z`.
- Ensure no generated Gradle output, secret files, signing material, consumer project state, or local environment files are staged.

In normal releases, do not stage:

```text
env.json
.devsecretsmanager
.gradle
build
```

## Tag

Create a Git tag using only the SemVer release version.

```powershell
git tag X.Y.Z
```

Example:

```powershell
git tag 0.4.1
```

Do not prefix the tag with `v`.

Use an annotated tag only if the user or repository policy asks for one. The tag name still must not use `v`:

```powershell
git tag -a X.Y.Z -m "Release X.Y.Z"
```

## Push

Push the branch:

```powershell
git push origin main
```

Push the release tag:

```powershell
git push origin X.Y.Z
```

If the branch is not `main`, verify the target branch with the user or repository policy before pushing.

## Final Check

Confirm the working tree is clean or only contains intentionally untracked local files:

```powershell
git status --short
```

Confirm the tag points at the release commit:

```powershell
git tag --points-at HEAD
```

Confirm the tag exists on the remote:

```powershell
git ls-remote --tags origin X.Y.Z
```

## Safety Notes

- Do not stage local project environment files, secret files, generated Gradle output, or signing material.
- Do not stage consumer-generated `.gitmodules`, `Tools/`, `Project.json`, or project build output unless the user explicitly asks for that repository state.
- Do not run destructive cleanup unless explicitly requested.
- Do not create tags before the final release commit exists.
- If tests or validation require network access, real key uploads, or a real Maven Central publish, ask for approval before running them.

## Future Improvement

A more automated release flow could later:

- Read the latest tag.
- Calculate the next SemVer version from conventional commits.
- Update `MavenCentralPublisher.ps1`, `README.md`, and `CHANGELOG.md`.
- Run safe validations.
- Create the release commit and tag.

Until that exists, agents should follow this manual release workflow.
