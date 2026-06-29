# Release Version Guide

This file defines the required workflow for releasing changes from this repository to the remote Git repository.

## Release Flow

Do not clear, reset, overwrite, stage, or commit local secrets as part of a release.

Secrets are machine-local values managed by `DevSecretsManagerPs`. They are not release artifacts, they are not part of the Git working tree, and they can vary per developer or build machine.

Only validate that tracked files do not contain real Sonatype credentials, signing keys, signing passwords, or other secret values.

Update the script version in:

```text
MavenCentralPublisher.ps1
```

Choose the next version based on the changes made before editing the version value.

Example version:

```text
0.1.1
```

Use semantic versioning to decide which part of the version must be increased:

- Increase **Major** for breaking changes, removed commands, renamed flags, incompatible output changes, incompatible secret names, incompatible Gradle property names, incompatible file layout changes, or any change that requires consumers to update their usage.
- Increase **Minor** for new commands, new flags, new behavior, new supported publishing workflows, new reusable Gradle publishing behavior, new documentation workflows, or backward-compatible features.
- Increase **Patch** for bug fixes, help text fixes, README fixes, release guide fixes, agent guide fixes, small internal improvements, or any change that does not alter public behavior.

Examples:

```text
0.1.0 -> 0.1.1  Patch
0.1.0 -> 0.2.0  Minor
0.1.0 -> 1.0.0  Major
```

Also update any documentation that shows the current version, such as:

```text
README.md
```

## Update Help And Documentation

Always update the command help exposed by:

```powershell
.\MavenCentralPublisher.ps1 -Help
```

The `-Help` output must describe the current commands, flags, behavior, return values, required parameters, and important safety rules.

Also update repository documentation when the change affects usage, installation, release flow, Gradle publishing behavior, or agent instructions:

```text
README.md
Agent-JvmMavenCentralPublisherPs.MD
Version.MD
```

Keep the README as the source of truth for tool usage and available commands. Keep `Agent-JvmMavenCentralPublisherPs.MD` focused on installation, dependency layout, consumer project preparation, and publish workflow only.

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

Do not run `-List`, `-Set`, `-Edit`, or `-Publish` as part of a normal release validation unless the release explicitly requires reading or changing local secrets, or performing a real Maven Central publication.

If list-related behavior changed, validate `-List` only in a controlled environment with dummy secrets.

## Stage Changes

Stage only the files required for the release.

Do not stage local project environment files, secret files, generated Gradle output, or signing material unless the release explicitly requires them.

In normal releases, do not stage:

```text
env.json
.devsecretsmanager
.gradle
build
```

Example:

```powershell
git add MavenCentralPublisher.ps1 publish.gradle.kts README.md Agent-JvmMavenCentralPublisherPs.MD Version.MD CHANGELOG.md
```

Adjust the staged file list to match the actual changes.

## Commit

Create a commit with a message that describes the changes made.

Example:

```powershell
git commit -m "Release 0.1.1"
```

For feature releases, the commit message may include the main change:

```powershell
git commit -m "Release 0.1.1 with Maven Central publish workflow"
```

## Tag

Create an annotated tag using only the release version.

Example:

```powershell
git tag -a 0.1.1 -m "Release 0.1.1"
```

## Push

Push the branch:

```powershell
git push origin main
```

Push the release tag:

```powershell
git push origin 0.1.1
```

## Final Check

Confirm the working tree is clean or only contains intentionally untracked local files:

```powershell
git status --short
```

Confirm the tag points at the release commit:

```powershell
git tag --points-at HEAD
```
