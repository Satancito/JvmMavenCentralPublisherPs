# JvmMavenCentralPublisherPs

PowerShell tool for preparing and publishing JVM artifacts to Sonatype Maven Central using Gradle.

The tool manages Maven Central credentials and signing configuration through `DevSecretsManagerPs`, exports the required environment variables for Gradle, verifies the signing public key against configured GPG key servers, and runs the reusable Gradle publishing task from `publish.gradle.kts`.

## Repository Layout

```text
MavenCentralPublisher.ps1
publish.gradle.kts
Agent-JvmMavenCentralPublisherPs.MD
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

## Install In A Consuming Project

Use the agent guide as the installation flow. The raw GitHub URL is:

[Agent-JvmMavenCentralPublisherPs.MD](https://raw.githubusercontent.com/Satancito/JvmMavenCentralPublisherPs/main/Agent-JvmMavenCentralPublisherPs.MD)

Prompt to use in the consuming repository:

```text
You are in the root of the consuming repository. Read and follow the workflow from:

https://raw.githubusercontent.com/Satancito/JvmMavenCentralPublisherPs/main/Agent-JvmMavenCentralPublisherPs.MD

Install and configure the JvmMavenCentralPublisherPs tool as described there, but do not run -Publish and do not publish any artifact. Stop after the project is prepared, required files are copied, and missing required properties are created with empty values.
```

The installation flow creates or updates the tool submodules, copies `Agent-JvmMavenCentralPublisherPs.MD` to the consuming repository root, copies `publish.gradle.kts` to the Gradle wrapper directory, applies that Gradle script from `build.gradle.kts`, and ensures the required `gradle.properties` keys exist.

## Commands

```powershell
.\MavenCentralPublisher.ps1 -Init
.\MavenCentralPublisher.ps1 -List
.\MavenCentralPublisher.ps1 -Edit [-Editor <editor>]
.\MavenCentralPublisher.ps1 -Set [-JavaExecutable <value>] [-SigningPrivateKey <value>] [-SigningPublicKey <value>] [-Username <value>] [-Password <value>] [-PublishingType <automatic|user_managed>] [-SigningPassword <value>]
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

`SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS` is initialized and repaired with these default servers:

```text
keyserver.ubuntu.com
pgp.mit.edu
keys.openpgp.org
```

The GPG server value is always validated as a non-empty string array. Empty strings and null values are removed, and the default servers are ensured.

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
repairs the GPG key server list
publishes and verifies the signing public key on configured GPG key servers
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
0.3.3
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
