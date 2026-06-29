import java.net.HttpURLConnection
import java.net.URI
import java.time.Year
import java.util.Base64
import org.gradle.api.GradleException
import org.gradle.api.publish.maven.MavenPublication
import org.gradle.api.publish.PublishingExtension
import org.gradle.api.plugins.JavaPluginExtension
import org.gradle.plugins.signing.SigningExtension

plugins.apply("maven-publish")
plugins.apply("signing")

val _SONATYPE_CENTRAL_PORTAL_DEPLOY_URL =
    "https://ossrh-staging-api.central.sonatype.com/service/local/staging/deploy/maven2/"
val _SONATYPE_CENTRAL_PORTAL_UPLOAD_URL =
    "https://ossrh-staging-api.central.sonatype.com/manual/upload/defaultRepository"
val _MAVEN_PUBLICATION_NAME = "mavenJava"
val _MAVEN_PUBLICATION_COMPONENT_NAME = "java"
val _SONATYPE_CENTRAL_PORTAL_REPOSITORY_NAME = "sonatypeCentralPortal"
val _UPLOAD_RELEASE_TASK_NAME = "uploadReleaseToCentralPortal"
val _PUBLISH_RELEASE_TASK_NAME = "publishReleaseToCentralPortal"
val _TEST_TASK_NAME = "test"
val _DEFAULT_PUBLISHING_TYPE = "user_managed"
val _AUTOMATIC_PUBLISHING_TYPE = "automatic"
val _UNSPECIFIED_PROJECT_VALUE = "unspecified"

val _ARTIFACT_ID_PROPERTY = "SONATYPE_MAVEN_CENTRAL_ARTIFACT_ID"
val _POM_URL_PROPERTY = "SONATYPE_MAVEN_CENTRAL_POM_URL"
val _INCEPTION_YEAR_PROPERTY = "SONATYPE_MAVEN_CENTRAL_INCEPTION_YEAR"
val _LICENSE_NAME_PROPERTY = "SONATYPE_MAVEN_CENTRAL_LICENSE_NAME"
val _LICENSE_URL_PROPERTY = "SONATYPE_MAVEN_CENTRAL_LICENSE_URL"
val _DEVELOPER_ID_PROPERTY = "SONATYPE_MAVEN_CENTRAL_DEVELOPER_ID"
val _DEVELOPER_NAME_PROPERTY = "SONATYPE_MAVEN_CENTRAL_DEVELOPER_NAME"
val _SCM_URL_PROPERTY = "SONATYPE_MAVEN_CENTRAL_SCM_URL"
val _SCM_CONNECTION_PROPERTY = "SONATYPE_MAVEN_CENTRAL_SCM_CONNECTION"
val _SCM_DEVELOPER_CONNECTION_PROPERTY = "SONATYPE_MAVEN_CENTRAL_SCM_DEVELOPER_CONNECTION"

val _USERNAME_ENV = "SONATYPE_MAVEN_CENTRAL_USERNAME"
val _PASSWORD_ENV = "SONATYPE_MAVEN_CENTRAL_PASSWORD"
val _PUBLISHING_TYPE_ENV = "SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE"
val _SIGNING_PRIVATE_KEY_ENV = "SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY"
val _SIGNING_PASSWORD_ENV = "SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD"

fun gradleProperty(name: String) = providers.gradleProperty(name)

fun secret(name: String) = providers.environmentVariable(name)

fun optionalSecret(name: String) = secret(name).orNull?.takeIf { it.isNotBlank() }

fun requiredSecret(name: String) =
    optionalSecret(name) ?: throw GradleException("Missing required environment variable: $name")

fun requiredGradleProperty(name: String): String =
    gradleProperty(name).orNull?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing required Gradle property or value is blank: $name")

fun requiredProjectValue(name: String, value: Any?): String {
    val text = value?.toString()?.takeIf { it.isNotBlank() && it != _UNSPECIFIED_PROJECT_VALUE }
    return text ?: throw GradleException("Project $name must be configured before publishing to Maven Central.")
}

fun requiredPublishingType(value: String): String {
    if (value !in setOf(_DEFAULT_PUBLISHING_TYPE, _AUTOMATIC_PUBLISHING_TYPE)) {
        throw GradleException("$_PUBLISHING_TYPE_ENV must be $_DEFAULT_PUBLISHING_TYPE or $_AUTOMATIC_PUBLISHING_TYPE.")
    }

    return value
}

fun requiredArtifactId(value: String): String {
    val artifactIdPattern = Regex("[A-Za-z0-9]+(-[A-Za-z0-9]+)*")
    if (!artifactIdPattern.matches(value)) {
        throw GradleException(
            "$_ARTIFACT_ID_PROPERTY must contain only letters, numbers, and hyphen-separated segments."
        )
    }

    return value
}

fun requiredInceptionYear(value: String): String {
    val year = value.toIntOrNull()
        ?: throw GradleException("$_INCEPTION_YEAR_PROPERTY must be a numeric year.")
    val currentYear = Year.now().value
    if (year !in 1900..currentYear) {
        throw GradleException("$_INCEPTION_YEAR_PROPERTY must be between 1900 and $currentYear.")
    }

    return value
}

fun isMavenCentralPublishRequested(): Boolean =
    gradle.startParameter.taskNames.any {
        val taskName = it.substringAfterLast(':')
        taskName == _PUBLISH_RELEASE_TASK_NAME ||
            taskName == _UPLOAD_RELEASE_TASK_NAME ||
            taskName == "publish" ||
            (taskName.startsWith("publish") && taskName.contains(_SONATYPE_CENTRAL_PORTAL_REPOSITORY_NAME.replaceFirstChar { char -> char.uppercase() }))
    }

val mavenCentralPublishRequested = isMavenCentralPublishRequested()

plugins.withId("java") {
    extensions.configure<JavaPluginExtension> {
        withSourcesJar()
        withJavadocJar()
    }
}

if (mavenCentralPublishRequested) {
    val projectGroupValue = requiredProjectValue("group", project.group)
    val projectVersionValue = requiredProjectValue("version", project.version)
    val projectNameValue = requiredProjectValue("name", project.name)
    val projectDescriptionValue = requiredProjectValue("description", project.description)

    val artifactIdValue = requiredArtifactId(requiredGradleProperty(_ARTIFACT_ID_PROPERTY))
    val pomUrlValue = requiredGradleProperty(_POM_URL_PROPERTY)
    val inceptionYearValue = requiredInceptionYear(requiredGradleProperty(_INCEPTION_YEAR_PROPERTY))
    val licenseNameValue = requiredGradleProperty(_LICENSE_NAME_PROPERTY)
    val licenseUrlValue = requiredGradleProperty(_LICENSE_URL_PROPERTY)
    val developerIdValue = requiredGradleProperty(_DEVELOPER_ID_PROPERTY)
    val developerNameValue = requiredGradleProperty(_DEVELOPER_NAME_PROPERTY)
    val scmUrlValue = requiredGradleProperty(_SCM_URL_PROPERTY)
    val scmConnectionValue = requiredGradleProperty(_SCM_CONNECTION_PROPERTY)
    val scmDeveloperConnectionValue = requiredGradleProperty(_SCM_DEVELOPER_CONNECTION_PROPERTY)

    val sonatypeCentralUsernameValue = requiredSecret(_USERNAME_ENV)
    val sonatypeCentralPasswordValue = requiredSecret(_PASSWORD_ENV)
    val sonatypeCentralPublishingTypeValue = requiredPublishingType(requiredSecret(_PUBLISHING_TYPE_ENV))
    val signingPrivateKeyValue = requiredSecret(_SIGNING_PRIVATE_KEY_ENV)
    val signingPasswordValue = requiredSecret(_SIGNING_PASSWORD_ENV)

    plugins.withId(_MAVEN_PUBLICATION_COMPONENT_NAME) {
        extensions.configure<PublishingExtension> {
            publications {
                create<MavenPublication>(_MAVEN_PUBLICATION_NAME) {
                    groupId = projectGroupValue
                    artifactId = artifactIdValue
                    version = projectVersionValue

                    val selectedComponentName = _MAVEN_PUBLICATION_COMPONENT_NAME
                    val selectedComponent = components.findByName(selectedComponentName)
                        ?: throw GradleException("Component '$selectedComponentName' was not found. Apply a JVM plugin before publishing to Maven Central.")
                    from(selectedComponent)

                    pom {
                        name.set(projectNameValue)
                        description.set(projectDescriptionValue)
                        url.set(pomUrlValue)

                        inceptionYear.set(inceptionYearValue)

                        licenses {
                            license {
                                name.set(licenseNameValue)
                                url.set(licenseUrlValue)
                            }
                        }

                        developers {
                            developer {
                                id.set(developerIdValue)
                                name.set(developerNameValue)
                            }
                        }

                        scm {
                            url.set(scmUrlValue)
                            connection.set(scmConnectionValue)
                            developerConnection.set(scmDeveloperConnectionValue)
                        }
                    }
                }
            }

            repositories {
                maven {
                    name = _SONATYPE_CENTRAL_PORTAL_REPOSITORY_NAME
                    url = uri(_SONATYPE_CENTRAL_PORTAL_DEPLOY_URL)

                    credentials {
                        username = sonatypeCentralUsernameValue
                        password = sonatypeCentralPasswordValue
                    }
                }
            }
        }

        extensions.configure<SigningExtension> {
            useInMemoryPgpKeys(signingPrivateKeyValue, signingPasswordValue)

            val publishing = extensions.getByType<PublishingExtension>()
            val publication = publishing.publications.getByName(_MAVEN_PUBLICATION_NAME)
            sign(publication)
        }

        tasks.register(_UPLOAD_RELEASE_TASK_NAME) {
            group = "publishing"
            description = "Uploads the staged deployment from the OSSRH compatibility endpoint into the Sonatype Central Portal."
            val publicationTaskName = _MAVEN_PUBLICATION_NAME.replaceFirstChar { it.uppercase() }
            val repositoryTaskName = _SONATYPE_CENTRAL_PORTAL_REPOSITORY_NAME.replaceFirstChar { it.uppercase() }
            dependsOn(
                "publish${publicationTaskName}PublicationTo${repositoryTaskName}Repository"
            )

            doLast {
                val namespace = projectGroupValue
                val authorization = Base64.getEncoder().encodeToString(
                    "$sonatypeCentralUsernameValue:$sonatypeCentralPasswordValue".toByteArray()
                )
                val portalUploadUrl = _SONATYPE_CENTRAL_PORTAL_UPLOAD_URL.trimEnd('/')
                val uploadUrl = URI.create(
                    "$portalUploadUrl/$namespace?publishing_type=$sonatypeCentralPublishingTypeValue"
                ).toURL()
                val connection = (uploadUrl.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Authorization", "Bearer $authorization")
                    doOutput = true
                    connectTimeout = 30_000
                    readTimeout = 30_000
                }

                val responseCode = connection.responseCode
                val responseBody = runCatching {
                    val stream = if (responseCode in 200..299) connection.inputStream else connection.errorStream
                    stream?.bufferedReader()?.use { it.readText() }.orEmpty()
                }.getOrDefault("")

                if (responseCode !in 200..299) {
                    val method = connection.requestMethod
                    val body = responseBody.ifBlank { "<empty>" }
                    throw GradleException(
                        "Central Portal upload failed. " +
                            "method=$method, " +
                            "url=$uploadUrl, " +
                            "status=$responseCode, " +
                            "namespace=$namespace, " +
                            "publishingType=$sonatypeCentralPublishingTypeValue, " +
                            "response=$body"
                    )
                }

                logger.lifecycle("Central Portal upload accepted: $responseBody")
            }
        }
    }
}

tasks.register(_PUBLISH_RELEASE_TASK_NAME) {
    group = "publishing"
    description = "Publishes signed Maven artifacts and submits the deployment to the Sonatype Central Portal."

    val testTask = tasks.findByName(_TEST_TASK_NAME)
    if (testTask != null) {
        dependsOn(testTask)
    }
    if (mavenCentralPublishRequested) {
        dependsOn(_UPLOAD_RELEASE_TASK_NAME)
    }
}
