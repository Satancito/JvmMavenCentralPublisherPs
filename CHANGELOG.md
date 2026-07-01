# Changelog

## Unreleased

## 2.2.1

- Changed Gradle publish execution to wait explicitly for the wrapper process, using `cmd.exe /d /c call` for `gradlew.bat` on Windows while preserving captured output in the publish JSON.
- Changed Gradle wrapper configuration to prefer the agnostic `gradlew` path on every platform, automatically resolving to `gradlew.bat` on Windows when available.

## 2.2.0

- Changed `-Publish` to return a more explicit capturable JSON contract for agents, including `Success`, `Command`, `Stage`, `MavenCentralUploadAccepted`, `RequiresManualRelease`, `PublicKeyUpload`, and `Gradle` fields.

## 2.1.1

- Changed GPG key server handling to explicitly validate the final upload URL list every time it is resolved, including non-empty HTTP/HTTPS URLs and the presence of all 3 default upload URLs.

## 2.1.0

- Changed `-Edit` to print launched editor information with non-capturable output and return no pipeline value.
- Added `-Init` copying for `publish.gradle.kts` from the tool directory to the consumer project root resolved as `../..` from `MavenCentralPublisher.ps1`, with automatic staging and committing of that copied file in the consumer Git repository when it changes.

## 2.0.1

- Fixed secret listing integration to use the current `DevSecretsManagerPs` `-List` JSON contract instead of the removed `-Json` parameter.
- Changed `-List` to return only Maven Central publisher secret properties instead of every value stored by `DevSecretsManagerPs`.

## 2.0.0

- Changed operational command stdout to JSON for successful scalar, object, and array results; failures now return a JSON error object with exit code `1`, while `-Help` prints plain capturable help text.
- Changed `-List` to return the complete secrets JSON instead of a formatted table.
- Changed `-Set` to return a boolean JSON success value.
- Changed `-Edit` to return a JSON object reporting whether the editor started and which explicit editor was requested.
- Changed `-Init` to print interactive non-capturable progress for `env.json`, the environment id, the environment secrets JSON file, and Maven Central publisher secrets.
- Changed `-UploadSigningPublicKey` and `-Publish` to return structured JSON results, with Gradle output captured in the publish result.
- Changed `-Publish` to read the Gradle wrapper command from the consumer root `Project.json` file by default, keeping `-ProjectGradleCommand` as an optional override.
- Reworked the English and Spanish README files to follow the `DevSecretsManagerPs` documentation style and make the consumer install order explicit: `DevSecretsManagerPs` first, then `JvmMavenCentralPublisherPs`.
- Added Spanish release and usage documentation files and aligned `Version.MD` with the bilingual release workflow used by `DevSecretsManagerPs`.
- Clarified `Version.MD` release ordering: determine scope and version, create staged technical Conventional Commits, make the final version bump commit, then tag and push.

## 1.0.0

- Fixed file reads to avoid `Get-Content -Raw`, improving compatibility with environments where that parameter is unavailable.
- Added README instructions for installing the tool and `DevSecretsManagerPs` with `ToolsManagerPs`.
- Removed the legacy installation guide file and its installation references.
- Updated `Version.MD` to follow the `ToolsManagerPs` release workflow style, with an explicit Conventional Commits section, repository-only scope, and the existing changelog heading format.

## 0.4.0

- Added `-UploadSigningPublicKey` to upload the configured signing public key to GPG key servers with native PowerShell HTTP requests and print per-server upload results.
- Added `-UploadSigningPublicKey -File <path>` to upload a public key directly from a file without updating secrets.
- Changed publish-time GPG key handling to use the same HTTP upload flow and require at least 2 configured upload URLs to accept the key before continuing to Gradle publish.
- Changed `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS` values to direct upload URLs, while migrating legacy host values to their known upload URLs during repair.
- Changed `-Publish` to require `SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY` and stop when the key cannot be uploaded to at least 2 configured upload URLs.

## 0.3.3

- Replaced `const val` declarations in `publish.gradle.kts` with script `val` declarations for compatibility when applied from another Gradle script.
- Delayed Maven publication, signing, and upload task configuration in `publish.gradle.kts` until the `java` plugin is available.

## 0.3.2

- Fixed file path handling for `-SigningPrivateKey` and `-SigningPublicKey` so existing paths with spaces are read as file content instead of being stored as literal path values.

## 0.3.1


## 0.3.0

- Added `-Set` support for reading `-SigningPrivateKey` and `-SigningPublicKey` from an existing file path.

## 0.2.2

- Changed `publish.gradle.kts` so required Gradle properties, project metadata, and environment variables are resolved only when a Maven Central publish task is requested.

## 0.2.1

- Expanded `README.md` with complete command usage, flags, install guidance, Gradle publishing notes, and safety rules.
- Added a raw GitHub agent-guide prompt for installing the tool in a consuming repository without running `-Publish`.

## 0.2.0

- Added `MavenCentralPublisher.ps1` with `-Init`, `-List`, `-Edit`, `-Set`, `-Publish`, `-Help`, and `-Version`.
- Added Maven Central secret management through `DevSecretsManagerPs`.
- Added environment-variable precedence over stored secrets for publish behavior.
- Added validation and repair for `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS`.
- Added `-ProjectGradleCommand` for passing the consumer project's `gradlew` or `gradlew.bat` command directly.
- Added reusable `publish.gradle.kts` for Maven Central publishing through Gradle.
- Added required Gradle property validation, project metadata validation, artifact id validation, inception year validation, signing configuration, and Sonatype Central upload task wiring.
- Added `Version.MD` with release workflow guidance.
