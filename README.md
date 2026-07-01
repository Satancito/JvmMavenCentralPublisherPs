# JvmMavenCentralPublisherPs

PowerShell tool for preparing and publishing JVM artifacts to Sonatype Maven Central using Gradle.

The tool manages Maven Central credentials and signing configuration through `DevSecretsManagerPs`, exports the required environment variables for Gradle, uploads the signing public key to configured GPG key servers through native PowerShell HTTP requests, and runs the reusable Gradle publishing task from `publish.gradle.kts`.

## Repository Layout

```text
MavenCentralPublisher.ps1
publish.gradle.kts
Version.MD
CHANGELOG.md
```

`MavenCentralPublisher.ps1` expects `DevSecretsManagerPs` to exist in the sibling directory:

```text
../DevSecretsManagerPs/SecretsManager.ps1
```

When this repository is installed as a tool inside a consuming project, the expected layout is:

```text
Tools/DevSecretsManagerPs
Tools/JvmMavenCentralPublisherPs
```

## Install In A Consumer Project With ToolsManagerPs

Consumer projects can install this repository as a tool by using `ToolsManagerPs`.

Download `ProjectManager.ps1` in the consumer project root:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Satancito/ToolsManagerPs/main/ProjectManager.ps1" -OutFile "ProjectManager.ps1" -UseBasicParsing
```

Initialize the consumer project configuration:

```powershell
.\ProjectManager.ps1 -Init
```

Add `DevSecretsManagerPs` as a Git submodule tool:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
```

Add `JvmMavenCentralPublisherPs` as a Git submodule tool:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName JvmMavenCentralPublisherPs -RepositoryUrl https://github.com/Satancito/JvmMavenCentralPublisherPs.git -Tag ""
```

`-Tag ""` stores `Tag` as `null`. A `null` tag means the tool is updated to the latest remote commit when `-Tools Update` runs.

The `-Tag` value can be:

- `null`, by passing `-Tag ""`, to track the latest remote commit.
- A Git tag, to pin the tool to a released version.
- A Git commit SHA, to pin the tool to an exact commit.

## Commands

```powershell
.\MavenCentralPublisher.ps1 -Init
.\MavenCentralPublisher.ps1 -List
.\MavenCentralPublisher.ps1 -Edit [-Editor <editor>]
.\MavenCentralPublisher.ps1 -Set [-JavaExecutable <value>] [-SigningPrivateKey <value>] [-SigningPublicKey <value>] [-Username <value>] [-Password <value>] [-PublishingType <automatic|user_managed>] [-SigningPassword <value>]
.\MavenCentralPublisher.ps1 -UploadSigningPublicKey [-File <path-to-public-key>]
.\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand <path-to-gradlew>
.\MavenCentralPublisher.ps1 -Help
.\MavenCentralPublisher.ps1 -Version
```

Aliases:

```powershell
.\MavenCentralPublisher.ps1 -h
.\MavenCentralPublisher.ps1 -help
.\MavenCentralPublisher.ps1 -usage
.\MavenCentralPublisher.ps1 -v
```

## -Init

Initializes `DevSecretsManagerPs` and creates missing Maven Central publisher secrets.

```powershell
.\MavenCentralPublisher.ps1 -Init
```

Created secrets:

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

`SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS` is initialized and repaired with these default upload URLs:

```text
http://keyserver.ubuntu.com:11371/pks/add
http://pgp.mit.edu:11371/pks/add
https://keys.openpgp.org/pks/add
```

The GPG server value is always validated as a non-empty string array of absolute HTTP/HTTPS upload URLs. Empty strings and null values are removed, legacy host values are migrated to their upload URLs, and the default upload URLs are ensured.

## -List

Lists Maven Central publisher secrets in table format.

```powershell
.\MavenCentralPublisher.ps1 -List
```

This command reads local secrets. Do not run it in logs or shared terminals where secret values could be exposed.

## -Edit

Opens the underlying `DevSecretsManagerPs` secrets file in an editor.

```powershell
.\MavenCentralPublisher.ps1 -Edit
.\MavenCentralPublisher.ps1 -Edit -Editor code
```

Before opening the file, the tool validates and repairs `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS`.

Use this only when direct manual editing is needed.

## -Set

Updates only the values explicitly passed.

```powershell
.\MavenCentralPublisher.ps1 -Set -JavaExecutable "C:\Program Files\Eclipse Adoptium\jdk-17\bin\java.exe"
.\MavenCentralPublisher.ps1 -Set -SigningPrivateKey "<private-key>"
.\MavenCentralPublisher.ps1 -Set -SigningPrivateKey ".\private-key.asc"
.\MavenCentralPublisher.ps1 -Set -SigningPublicKey "<public-key>"
.\MavenCentralPublisher.ps1 -Set -SigningPublicKey ".\public-key.asc"
.\MavenCentralPublisher.ps1 -Set -SigningPassword "<signing-password>"
.\MavenCentralPublisher.ps1 -Set -Username "<sonatype-token-username>"
.\MavenCentralPublisher.ps1 -Set -Password "<sonatype-token-password>"
.\MavenCentralPublisher.ps1 -Set -PublishingType automatic
.\MavenCentralPublisher.ps1 -Set -PublishingType user_managed
```

Supported flags:

```text
-JavaExecutable
-SigningPrivateKey
-SigningPublicKey
-SigningPassword
-Username
-Password
-PublishingType
```

`-PublishingType` uses `ValidateSet` and accepts:

```text
automatic
user_managed
empty string
null
```

Null values are stored as null. Empty strings are stored as empty secret values. `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS` is intentionally not handled by `-Set`.

`-SigningPrivateKey` and `-SigningPublicKey` accept either literal key content or a path to an existing key file. When the value is a valid file path, the file is read with `Get-Content -Raw` and the file content is stored as the secret value.

## -UploadSigningPublicKey

Uploads `SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY` to the configured GPG key server upload URLs.

```powershell
.\MavenCentralPublisher.ps1 -UploadSigningPublicKey
.\MavenCentralPublisher.ps1 -UploadSigningPublicKey -File ".\public-key.asc"
```

The command uses the same secret resolution rules as publish: environment variables have priority over stored secrets when they are not null or empty.

When `-File` is provided, the file content is used as the public key for that upload only. It does not update the stored secret.

Each configured upload URL is attempted independently using native PowerShell HTTP requests. No `gpg` executable or external key-management tool is required. The command prints upload status in a table and fails when any configured URL does not accept the upload.

## -Publish

Publishes a JVM artifact to Sonatype Maven Central through the Gradle wrapper command passed by `-ProjectGradleCommand`.

```powershell
.\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand "..\MyJvmProject\gradlew.bat"
.\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand "../MyJvmProject/gradlew"
```

`-ProjectGradleCommand` must point directly to `gradlew.bat` on Windows or `gradlew` on Unix-like systems. The tool uses the directory that contains that command as the Gradle project directory.

During publish, the tool:

```text
validates secrets and environment variables
repairs the GPG key server upload URL list
uploads the signing public key to configured GPG key server upload URLs using native PowerShell HTTP requests
sets environment variables for Gradle using the same names as the secrets
sets JAVA_HOME from SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE
runs publishReleaseToCentralPortal through the provided Gradle wrapper command
```

Environment variables have priority over stored secrets when they are not null or empty.

Required values for publish:

```text
SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE
SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY
SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD
SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY
SONATYPE_MAVEN_CENTRAL_PASSWORD
SONATYPE_MAVEN_CENTRAL_USERNAME
```

`SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY` is required for publish and must upload successfully to every configured GPG key server upload URL before Gradle runs.


`SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE` defaults to `user_managed` when empty.

## -Help

Prints command usage.

```powershell
.\MavenCentralPublisher.ps1 -Help
```

## -Version

Prints the script version.

```powershell
.\MavenCentralPublisher.ps1 -Version
```

Current version:

```text
1.0.0
```

## Gradle Publishing Script

`publish.gradle.kts` is copied into the directory that contains the consumer project's Gradle wrapper.

The consumer `build.gradle.kts` must apply it:

```kotlin
apply(from = "publish.gradle.kts")
```

The consumer project must define:

```kotlin
group = ""
version = ""
description = ""
```

The reusable script reads `project.group`, `project.version`, `project.name`, and `project.description` from Gradle. It fails if any required project value is missing, blank, or `unspecified`.

Only these Gradle properties are required in the Gradle project directory:

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

Secrets are read by `publish.gradle.kts` from environment variables provided by `MavenCentralPublisher.ps1`, and the required Gradle properties, project metadata, and environment variables are resolved only when a Maven Central publish task is requested.

## Safety

Do not commit real secrets, private keys, signing passwords, Sonatype token values, local secret stores, Gradle caches, or generated build output.

Do not run `-Publish` unless you intentionally want to publish an artifact to Maven Central.
