# JvmMavenCentralPublisherPs

`JvmMavenCentralPublisherPs` is a PowerShell tool for preparing and publishing JVM artifacts to Sonatype Maven Central with Gradle.

The tool stores Maven Central credentials and signing configuration through `DevSecretsManagerPs`, exports the required environment variables for Gradle, uploads the signing public key to configured GPG key server upload URLs with native PowerShell HTTP requests, and runs the reusable Gradle publishing task from `publish.gradle.kts`.

## Script

```powershell
.\MavenCentralPublisher.ps1
```

Current version:

```powershell
.\MavenCentralPublisher.ps1 -Version
```

Returns:

```text
"2.1.0"
```

`-Version` and `-Help` do not initialize secrets, create files, or publish artifacts.

This script expects `DevSecretsManagerPs` to exist in the sibling directory:

```text
../DevSecretsManagerPs/SecretsManager.ps1
```

Commands that read or mutate secrets delegate storage to `DevSecretsManagerPs`.

Commands with capturable results write JSON to stdout. Scalar values are emitted as valid JSON scalars: booleans as `true` or `false`, strings as `"value"`, null as `null`, and empty strings as `""`. Command failures write a JSON error object and exit with code `1`. `-Help` prints plain help text so it can be captured directly. `-Init` and `-Edit` print interactive progress only and do not produce a capturable result.

This tool reads stored secrets through the current `DevSecretsManagerPs` contract: `SecretsManager.ps1 -List` returns the raw secrets JSON.

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

Install `DevSecretsManagerPs` first. `JvmMavenCentralPublisherPs` depends on this tool and expects it to be available as a sibling tool:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
```

Then install `JvmMavenCentralPublisherPs`:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName JvmMavenCentralPublisherPs -RepositoryUrl https://github.com/Satancito/JvmMavenCentralPublisherPs.git -Tag ""
```

The expected consumer project layout is:

```text
Tools/DevSecretsManagerPs
Tools/JvmMavenCentralPublisherPs
```

`-Tag ""` stores `Tag` as `null`. A `null` tag means the tool is updated to the latest remote commit when `-Tools Update` runs.

The `-Tag` value can be:

- `null`, by passing `-Tag ""`, to track the latest remote commit.
- A Git tag, to pin the tool to a released version.
- A Git commit SHA, to pin the tool to an exact commit.

## Files

### Repository Documentation

The following documentation files are part of this repository:

- `README.md`: main usage, installation, command, and behavior documentation in English.
- `README.es-ES.MD`: main usage, installation, command, and behavior documentation in Spanish.
- `CHANGELOG.md`: release history and unreleased changes.
- `Version.MD`: repository-local release workflow in English.
- `Version.es-ES.MD`: repository-local release workflow in Spanish.

`README.md` and `README.es-ES.MD` must stay aligned when usage, installation, commands, or behavior change.

`Version.MD` and `Version.es-ES.MD` are release workflow documents for this repository. They are not consumer-project setup files.

### Publishing Script

The reusable Gradle publishing script is:

```text
publish.gradle.kts
```

`-Init` copies `publish.gradle.kts` from the tool directory to the consumer project root, resolved as `../..` from `MavenCentralPublisher.ps1`, only when the root file is missing or different. When it copies the file, it stages and commits only `publish.gradle.kts` in the consumer project Git repository.

Apply it from the consumer `build.gradle.kts`:

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

### Secrets

Maven Central publisher values are stored through `DevSecretsManagerPs` using these secret names:

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

`SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS` is a string array of direct HTTP/HTTPS upload URLs. The default upload URLs are:

```text
http://keyserver.ubuntu.com:11371/pks/add
http://pgp.mit.edu:11371/pks/add
https://keys.openpgp.org/pks/add
```

The consumer project root must contain `Project.json` with a `Project` property that points to `gradlew.bat` or `gradlew`:

```json
{
  "Project": ".\\gradlew.bat"
}
```

Relative `Project` values are resolved from the consumer project root, which is `../../` from the tool directory.

## Validation

`-Init`, `-List`, `-Edit`, `-Set`, `-UploadSigningPublicKey`, and `-Publish` initialize and validate access to the sibling `DevSecretsManagerPs` tool before running.

The GPG key server upload URL list is validated and repaired whenever secrets are initialized or accessed by relevant commands:

- Null values and empty strings are removed.
- Legacy host values are migrated to direct upload URLs.
- The three default upload URLs are always ensured.
- The final value must be a non-empty string array of absolute HTTP/HTTPS upload URLs.

## Help

```powershell
.\MavenCentralPublisher.ps1 -Help
.\MavenCentralPublisher.ps1 -h
.\MavenCentralPublisher.ps1 -help
.\MavenCentralPublisher.ps1 -usage
```

Prints command usage as plain capturable text.

## Init

```powershell
.\MavenCentralPublisher.ps1 -Init
```

Initializes `DevSecretsManagerPs`, copies `publish.gradle.kts` to the consumer project root when needed, commits that copied file in the consumer Git repository, and creates missing Maven Central publisher secrets.

It also validates and repairs `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS`.

Prints interactive progress for `env.json`, the environment id, the copied `publish.gradle.kts`, the consumer Git commit for that file, the environment secrets JSON file, and Maven Central publisher secrets. It does not produce a capturable result.

## List

```powershell
.\MavenCentralPublisher.ps1 -List
```

Returns capturable JSON with only the Maven Central publisher secret properties handled by this tool, after validating and repairing Maven Central publisher values.

This command reads local secrets. Do not run it in logs or shared terminals where secret values could be exposed.

## Edit

```powershell
.\MavenCentralPublisher.ps1 -Edit
.\MavenCentralPublisher.ps1 -Edit -Editor <EditorName>
```

Opens the underlying `DevSecretsManagerPs` secrets file in an editor.

Before opening the file, the tool validates and repairs `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS`.

Prints which editor is launched using non-capturable output and returns no pipeline value.

## Set

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

Updates only the values explicitly passed.

Returns `true` when the provided values are stored.

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

`-SigningPrivateKey` and `-SigningPublicKey` accept either literal key content or a path to an existing key file. When the value is a valid file path, the file content is stored as the secret value.

## UploadSigningPublicKey

```powershell
.\MavenCentralPublisher.ps1 -UploadSigningPublicKey
.\MavenCentralPublisher.ps1 -UploadSigningPublicKey -File ".\public-key.asc"
```

Uploads `SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY` to the configured GPG key server upload URLs.

The command uses the same secret resolution rules as publish: environment variables have priority over stored secrets when they are not null or empty.

When `-File` is provided, the file content is used as the public key for that upload only. It does not update the stored secret.

Each configured upload URL is attempted independently using native PowerShell HTTP requests. No `gpg` executable or external key-management tool is required. The command returns a JSON array with upload results and fails when fewer than 2 configured upload URLs accept the upload.

## Publish

```powershell
.\MavenCentralPublisher.ps1 -Publish
.\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand "..\MyJvmProject\gradlew.bat"
```

Publishes a JVM artifact to Sonatype Maven Central through the Gradle wrapper command configured in the consumer root `Project.json` file.

By default, the script reads the `Project` property from `Project.json`. Relative values are resolved from the consumer project root. The value must point directly to `gradlew.bat` on Windows or `gradlew` on Unix-like systems.

`-ProjectGradleCommand` is an optional explicit override. When provided, it must point directly to `gradlew.bat` or `gradlew`.

The tool uses the directory that contains the resolved Gradle wrapper command as the Gradle project directory.

During publish, the tool:

- Validates secrets and environment variables.
- Repairs the GPG key server upload URL list.
- Uploads the signing public key to configured GPG key server upload URLs using native PowerShell HTTP requests.
- Sets environment variables for Gradle using the same names as the secrets.
- Sets `JAVA_HOME` from `SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE`.
- Runs `publishReleaseToCentralPortal` through the provided Gradle wrapper command.

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

`SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY` is required for publish and must upload successfully to at least 2 configured GPG key server upload URLs before Gradle runs.

`SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE` defaults to `user_managed` when empty.

The publish command returns a JSON object with `Published`, `GradleExitCode`, resolved paths, public key upload results, and captured Gradle output. If Gradle fails, the command returns a JSON error object and exits with code `1`.

## Version

```powershell
.\MavenCentralPublisher.ps1 -Version
.\MavenCentralPublisher.ps1 -v
```

Returns the script version as a JSON string.

```text
"2.1.0"
```

## Recommended Workflow

Install the required tools in the consumer project:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
.\ProjectManager.ps1 -Tools Add -RepositoryName JvmMavenCentralPublisherPs -RepositoryUrl https://github.com/Satancito/JvmMavenCentralPublisherPs.git -Tag ""
```

Initialize publisher secrets:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Init
```

Configure secrets:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -JavaExecutable "C:\Path\To\java.exe"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPrivateKey ".\private-key.asc"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPublicKey ".\public-key.asc"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPassword "<signing-password>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -Username "<sonatype-token-username>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -Password "<sonatype-token-password>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -PublishingType user_managed
```

Publish with the consumer project's Gradle wrapper:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Publish
```

## Safety

Do not commit real secrets, private keys, signing passwords, Sonatype token values, local secret stores, Gradle caches, or generated build output.

Do not run `-Publish` unless you intentionally want to publish an artifact to Maven Central.
