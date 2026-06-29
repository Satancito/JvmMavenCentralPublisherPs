# JVM Maven Central Publisher Agent Guide

This file defines the required workflow for installing and using `JvmMavenCentralPublisherPs` inside a consuming repository.

Your CWD must be the root of the consuming project.

The consuming repository must install two tools as Git submodules:

```text
Tools/DevSecretsManagerPs
Tools/JvmMavenCentralPublisherPs
```

Command usage documentation for this tool is in:

```text
./Tools/JvmMavenCentralPublisherPs/README.md
```

`MavenCentralPublisher.ps1` depends on `DevSecretsManagerPs` by relative path:

```powershell
..\DevSecretsManagerPs\SecretsManager.ps1
```

That path works because both tools live under `Tools`.

## Required Consumer Files

The consuming repository root must contain:

```text
ProjectPath.txt
```

`ProjectPath.txt` contains the relative path to the Gradle wrapper command used by the project.

Windows example:

```text
src/MyJvmProject/gradlew.bat
```

Unix-like example:

```text
src/MyJvmProject/gradlew
```

The directory that contains this `gradlew` or `gradlew.bat` is the Gradle project directory. This is not necessarily the same as the consuming repository root.

## Step 1: Add Or Update DevSecretsManagerPs

From the root of the consuming repository, ensure `DevSecretsManagerPs` exists as a submodule at:

```text
Tools/DevSecretsManagerPs
```

If it does not exist, add it:

```powershell
git submodule add https://github.com/Satancito/DevSecretsManagerPs.git Tools/DevSecretsManagerPs
```

If it already exists as a submodule in that directory, synchronize, initialize, and update it:

```powershell
git submodule sync --recursive Tools/DevSecretsManagerPs
git submodule update --init --recursive Tools/DevSecretsManagerPs
git submodule update --remote --recursive Tools/DevSecretsManagerPs
```

## Step 2: Add Or Update JvmMavenCentralPublisherPs

From the root of the consuming repository, ensure this project exists as a submodule at:

```text
Tools/JvmMavenCentralPublisherPs
```

If it does not exist, add it:

```powershell
git submodule add https://github.com/Satancito/JvmMavenCentralPublisherPs.git Tools/JvmMavenCentralPublisherPs
```

If it already exists as a submodule in that directory, synchronize, initialize, and update it:

```powershell
git submodule sync --recursive Tools/JvmMavenCentralPublisherPs
git submodule update --init --recursive Tools/JvmMavenCentralPublisherPs
git submodule update --remote --recursive Tools/JvmMavenCentralPublisherPs
```

When this tool repo is added or updated, always continue through Step 4 and copy the tool's current `Agent-JvmMavenCentralPublisherPs.MD` into the consuming repository root before applying the remaining steps.

## Step 3: Apply DevSecretsManagerPs Instructions

After `Tools/DevSecretsManagerPs` exists, apply the instructions from:

```text
Tools/DevSecretsManagerPs/Agent-DevSecretsManagerPs.MD
```

Do this before configuring or running `MavenCentralPublisher.ps1`.

## Step 4: Copy Publisher Agent File

Copy this file from the publisher tool into the root of the consuming repository:

```text
Tools/JvmMavenCentralPublisherPs/Agent-JvmMavenCentralPublisherPs.MD -> Agent-JvmMavenCentralPublisherPs.MD
```

The root copy gives future agents a predictable instruction file without searching inside the tool submodule.

After copying it, read the root copy:

```text
Agent-JvmMavenCentralPublisherPs.MD
```

Continue following the instructions from the root copy. Skip only the steps that have already been completed in the current run, such as adding or updating submodules and copying this agent file to the root. The remaining steps must be executed from the copied root version so the consuming repository uses the newest workflow from the updated tool.

## Step 5: Copy Gradle Publishing Script

Read `ProjectPath.txt` from the consuming repository root and resolve its value relative to the consuming repository root.

Copy:

```text
Tools/JvmMavenCentralPublisherPs/publish.gradle.kts
```

into the directory that contains the resolved `gradlew` or `gradlew.bat`.

Example:

```text
src/MyJvmProject/gradlew.bat
src/MyJvmProject/publish.gradle.kts
```

Always copy `publish.gradle.kts` when the publisher tool repo registers changes. Do not copy it to the consuming repository root unless the root is also the directory that contains `gradlew`.

## Step 6: Ensure Gradle Applies publish.gradle.kts

In the Gradle project directory, ensure the main `build.gradle.kts` applies the copied script:

```kotlin
apply(from = "publish.gradle.kts")
```

If the `apply` line is missing, add it once. Do not duplicate the reusable Maven Central publishing logic in the consumer `build.gradle.kts`.

Also ensure the main `build.gradle.kts` defines these project values:

```kotlin
group = ""
version = ""
description = ""
```

If any line is missing, create only the missing line with an empty value so the developer can fill it later. Do not overwrite existing values.

`publish.gradle.kts` reads these from:

```text
project.group
project.version
project.name
project.description
```

and fails if any required value is missing, blank, or `unspecified`.

## Step 7: Ensure Required Gradle Properties

In the Gradle project directory, ensure `gradle.properties` exists.

Only these Gradle properties are required by `publish.gradle.kts`. Verify they exist. If any are missing, add them with an empty value. Do not touch properties that already exist.

```properties
SONATYPE_MAVEN_CENTRAL_ARTIFACT_ID=
SONATYPE_MAVEN_CENTRAL_POM_URL=
SONATYPE_MAVEN_CENTRAL_INCEPTION_YEAR=
SONATYPE_MAVEN_CENTRAL_LICENSE_NAME=
SONATYPE_MAVEN_CENTRAL_LICENSE_URL=
SONATYPE_MAVEN_CENTRAL_DEVELOPER_ID=
SONATYPE_MAVEN_CENTRAL_DEVELOPER_NAME=
SONATYPE_MAVEN_CENTRAL_SCM_URL=
SONATYPE_MAVEN_CENTRAL_SCM_CONNECTION=
SONATYPE_MAVEN_CENTRAL_SCM_DEVELOPER_CONNECTION=
```

## Step 8: Confirm Required Publisher Configuration

Assume the developer has already configured the required environment variables, secrets, and Gradle properties before publishing.

The publisher uses these secrets and same-named environment variables:

```text
SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS
SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE
SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY
SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD
SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY
SONATYPE_MAVEN_CENTRAL_PASSWORD
SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE
SONATYPE_MAVEN_CENTRAL_USERNAME
```

Environment variables have priority over secrets when they are not null or empty.

Secret values are stored by `DevSecretsManagerPs` in the user's home directory. They are local to each machine and must never be committed.

## Step 9: Optional Secret Maintenance

Use `-Set` to update publisher secrets instead of editing JSON manually:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -JavaExecutable "<path-to-java>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPrivateKey "<private-key>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPrivateKey ".\private-key.asc"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPublicKey "<public-key>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPublicKey ".\public-key.asc"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPassword "<signing-password>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -Username "<sonatype-token-username>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -Password "<sonatype-token-password>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -PublishingType user_managed
```

Allowed publishing types:

```text
user_managed
automatic
```

## Step 10: Publish

This step is conditional.

If the user explicitly requested installation, preparation, update, configuration, or any other workflow that says not to publish, do not run this step. In that case, skip only Step 10 and continue with the remaining sections such as staging and commit guidance.

Read the relative Gradle wrapper command path from:

```text
ProjectPath.txt
```

Then publish with:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -ProjectGradleCommand <value-from-ProjectPath.txt> -Publish
```

Example:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -ProjectGradleCommand "src/MyJvmProject/gradlew.bat" -Publish
```

`MavenCentralPublisher.ps1` will:

```text
validate secrets and environment variables
publish and verify the signing public key on configured GPG key servers
set the required environment variables for Gradle
set JAVA_HOME from SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE
run publishReleaseToCentralPortal through the provided Gradle wrapper command
```

## Step 11: Stage Only Publisher Changes

Stage only publisher installation/update files when something actually changed.

There are publisher changes when:

- `Tools/JvmMavenCentralPublisherPs` was added.
- `Tools/JvmMavenCentralPublisherPs` revision changed after synchronize, initialize, or update.
- The copied `Agent-JvmMavenCentralPublisherPs.MD` changed.
- The copied `publish.gradle.kts` changed.
- `gradle.properties` gained missing required Maven Central properties with empty values.
- `build.gradle.kts` was updated to apply `publish.gradle.kts`.
- `ProjectPath.txt` was added or changed.

Typical first publisher install:

```powershell
git add .gitmodules Tools/JvmMavenCentralPublisherPs Agent-JvmMavenCentralPublisherPs.MD ProjectPath.txt
git add <gradle-project-directory>/publish.gradle.kts
git add <gradle-project-directory>/gradle.properties
git add <gradle-project-directory>/build.gradle.kts
```

Typical publisher update:

```powershell
git add Tools/JvmMavenCentralPublisherPs Agent-JvmMavenCentralPublisherPs.MD
git add <gradle-project-directory>/publish.gradle.kts
```

Do not stage `Tools/DevSecretsManagerPs` or `Agent-DevSecretsManagerPs.MD` from this guide. The `Agent-DevSecretsManagerPs.MD` workflow is responsible for its own stage and commit operations.

Never stage real secrets, private keys, passwords, machine-local secret files, Gradle caches, or generated build artifacts.

## Step 12: Commit

Commit staged installation or update changes with a clear message.

First install example:

```powershell
git commit -m "Add JVM Maven Central publisher"
```

Update example:

```powershell
git commit -m "Update JVM Maven Central publisher"
```

## Agent Rules

When working in a repository that uses this tool:

- Treat the current CWD as the consuming repository root.
- Treat `Tools/DevSecretsManagerPs` as the required secrets manager tool path.
- Treat `Tools/JvmMavenCentralPublisherPs` as the required JVM Maven Central publisher tool path.
- Use `git submodule add` only when the submodule does not already exist.
- If a submodule already exists in the required path, synchronize, initialize, and update it.
- When `Tools/JvmMavenCentralPublisherPs` is added or updated, always execute the workflow through copying `Agent-JvmMavenCentralPublisherPs.MD` to the consuming repository root before continuing.
- Apply `Tools/DevSecretsManagerPs/Agent-DevSecretsManagerPs.MD` before using the publisher.
- Keep updated copies of `Agent-DevSecretsManagerPs.MD` and `Agent-JvmMavenCentralPublisherPs.MD` in the consuming repository root when their source files changed.
- After copying `Agent-JvmMavenCentralPublisherPs.MD` to the consuming repository root, read that root copy and continue from it, skipping only steps already completed in the current run.
- Keep `ProjectPath.txt` in the consuming repository root and read it before publishing.
- Skip only the publish step when the user explicitly requested not to publish; still execute the preparation and staging guidance that applies.
- Copy `publish.gradle.kts` into the directory that contains `gradlew` or `gradlew.bat` whenever the publisher tool repo registers changes.
- Treat copied tool scripts as generated artifacts from `Tools/JvmMavenCentralPublisherPs`; do not locally fix or customize copied scripts in the consuming repository.
- If a copied script has a problem, update `Tools/JvmMavenCentralPublisherPs` to a newer version and copy the regenerated script again.
- Ensure the Gradle project's `build.gradle.kts` applies `publish.gradle.kts` exactly once.
- Ensure the Gradle project's `build.gradle.kts` contains `group`, `version`, and `description`, creating only missing assignments with empty values.
- Keep `gradle.properties` required Maven Central properties present, creating only missing keys with empty values.
- Do not overwrite existing `gradle.properties` values.
- Use `.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Init` before other publisher secret operations in a new environment.
- Use `.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set ...` to update publisher secrets instead of editing JSON manually.
- Use `.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Edit` only when the user explicitly wants to edit the underlying secrets file.
- Do not clear, overwrite, stage, commit, publish, or print actual secret values.
- Keep this guide focused on installation, dependency layout, consumer project preparation, and publish workflow.
