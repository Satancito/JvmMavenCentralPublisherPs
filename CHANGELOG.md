# Changelog

## Unreleased

## 0.4.0

- Added `-UploadSigningPublicKey` to upload the configured signing public key to GPG key servers with native PowerShell HTTP requests and print per-server upload results.
- Added `-UploadSigningPublicKey -File <path>` to upload a public key directly from a file without updating secrets.
- Changed publish-time GPG key handling to use the same HTTP upload flow and require every configured upload URL to accept the key before continuing to Gradle publish.
- Changed `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS` values to direct upload URLs, while migrating legacy host values to their known upload URLs during repair.
- Changed `-Publish` to require `SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY` and stop when the key cannot be uploaded to every configured upload URL.

## 0.3.3

- Replaced `const val` declarations in `publish.gradle.kts` with script `val` declarations for compatibility when applied from another Gradle script.
- Delayed Maven publication, signing, and upload task configuration in `publish.gradle.kts` until the `java` plugin is available.
- Added agent guidance to avoid locally fixing copied scripts in consuming repositories because they are regenerated from tool versions.

## 0.3.2

- Fixed file path handling for `-SigningPrivateKey` and `-SigningPublicKey` so existing paths with spaces are read as file content instead of being stored as literal path values.

## 0.3.1

- Clarified the consumer agent flow so tool updates always copy the newest root agent before continuing, and publish is skipped only when explicitly requested.

## 0.3.0

- Added `-Set` support for reading `-SigningPrivateKey` and `-SigningPublicKey` from an existing file path.

## 0.2.2

- Changed `publish.gradle.kts` so required Gradle properties, project metadata, and environment variables are resolved only when a Maven Central publish task is requested.

## 0.2.1

- Expanded `README.md` with complete command usage, flags, install guidance, Gradle publishing notes, and safety rules.
- Added a raw GitHub agent-guide prompt for installing the tool in a consuming repository without running `-Publish`.
- Clarified in `Agent-JvmMavenCentralPublisherPs.MD` that only the Gradle properties required by `publish.gradle.kts` should be created.
- Added guidance to read the copied root agent file after installing it in a consuming repository.
- Added `Agent-JvmMavenCentralPublisherPs.MD` guidance pointing command usage documentation to `./Tools/JvmMavenCentralPublisherPs/README.md`.

## 0.2.0

- Added `MavenCentralPublisher.ps1` with `-Init`, `-List`, `-Edit`, `-Set`, `-Publish`, `-Help`, and `-Version`.
- Added Maven Central secret management through `DevSecretsManagerPs`.
- Added environment-variable precedence over stored secrets for publish behavior.
- Added validation and repair for `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS`.
- Added `-ProjectGradleCommand` for passing the consumer project's `gradlew` or `gradlew.bat` command directly.
- Added reusable `publish.gradle.kts` for Maven Central publishing through Gradle.
- Added required Gradle property validation, project metadata validation, artifact id validation, inception year validation, signing configuration, and Sonatype Central upload task wiring.
- Added `Agent-JvmMavenCentralPublisherPs.MD` for installing and using the tool from a consuming repository.
- Added `Version.MD` with release workflow guidance.
