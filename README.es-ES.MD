# JvmMavenCentralPublisherPs

`JvmMavenCentralPublisherPs` es una herramienta PowerShell para preparar y publicar artefactos JVM en Sonatype Maven Central con Gradle.

La herramienta guarda credenciales de Maven Central y configuracion de firma mediante `DevSecretsManagerPs`, exporta las variables de entorno requeridas para Gradle, sube la public key de firma a las URLs de subida de servidores GPG configuradas usando requests HTTP nativos de PowerShell, y ejecuta la tarea reusable de publicacion Gradle desde `publish.gradle.kts`.

## Script

```powershell
.\MavenCentralPublisher.ps1
```

Version actual:

```powershell
.\MavenCentralPublisher.ps1 -Version
```

Retorna:

```text
"2.0.0"
```

`-Version` y `-Help` no inicializan secretos, no crean archivos y no publican artefactos.

Este script espera que `DevSecretsManagerPs` exista en el directorio hermano:

```text
../DevSecretsManagerPs/SecretsManager.ps1
```

Los comandos que leen o mutan secretos delegan el almacenamiento a `DevSecretsManagerPs`.

Los comandos con resultados capturables escriben JSON en stdout. Los valores escalares se emiten como escalares JSON validos: booleanos como `true` o `false`, strings como `"value"`, null como `null`, y strings vacios como `""`. Los fallos escriben un objeto JSON de error y salen con codigo `1`. `-Help` imprime ayuda como texto plano para que se pueda capturar directamente. `-Init` imprime solo progreso interactivo y no produce un resultado capturable.

## Instalar En Un Proyecto Consumidor Con ToolsManagerPs

Los proyectos consumidores pueden instalar este repositorio como herramienta usando `ToolsManagerPs`.

Descargar `ProjectManager.ps1` en la raiz del proyecto consumidor:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Satancito/ToolsManagerPs/main/ProjectManager.ps1" -OutFile "ProjectManager.ps1" -UseBasicParsing
```

Inicializar la configuracion del proyecto consumidor:

```powershell
.\ProjectManager.ps1 -Init
```

Instalar primero `DevSecretsManagerPs`. `JvmMavenCentralPublisherPs` depende de esta herramienta y espera que este disponible como herramienta hermana:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
```

Luego instalar `JvmMavenCentralPublisherPs`:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName JvmMavenCentralPublisherPs -RepositoryUrl https://github.com/Satancito/JvmMavenCentralPublisherPs.git -Tag ""
```

El layout esperado del proyecto consumidor es:

```text
Tools/DevSecretsManagerPs
Tools/JvmMavenCentralPublisherPs
```

`-Tag ""` guarda `Tag` como `null`. Un tag `null` significa que la herramienta se actualiza al ultimo commit remoto cuando se ejecuta `-Tools Update`.

El valor de `-Tag` puede ser:

- `null`, pasando `-Tag ""`, para seguir el ultimo commit remoto.
- Un Git tag, para fijar la herramienta a una version publicada.
- Un SHA de commit Git, para fijar la herramienta a un commit exacto.

## Archivos

### Documentacion Del Repositorio

Los siguientes archivos de documentacion son parte de este repositorio:

- `README.md`: documentacion principal de uso, instalacion, comandos y comportamiento en ingles.
- `README.es-ES.MD`: documentacion principal de uso, instalacion, comandos y comportamiento en espanol.
- `CHANGELOG.md`: historial de releases y cambios no publicados.
- `Version.MD`: flujo de release local del repositorio en ingles.
- `Version.es-ES.MD`: flujo de release local del repositorio en espanol.

`README.md` y `README.es-ES.MD` deben mantenerse alineados cuando cambie el uso, instalacion, comandos o comportamiento.

`Version.MD` y `Version.es-ES.MD` son documentos de flujo de release para este repositorio. No son archivos de configuracion de proyectos consumidores.

### Script De Publicacion

El script reusable de publicacion Gradle es:

```text
publish.gradle.kts
```

Copiar `publish.gradle.kts` en el directorio que contiene el Gradle wrapper del proyecto consumidor, y aplicarlo desde el `build.gradle.kts` consumidor:

```kotlin
apply(from = "publish.gradle.kts")
```

El proyecto consumidor debe definir:

```kotlin
group = ""
version = ""
description = ""
```

El script reusable lee `project.group`, `project.version`, `project.name`, y `project.description` desde Gradle. Falla si algun valor requerido del proyecto falta, esta en blanco, o es `unspecified`.

Solo estas propiedades Gradle son requeridas en el directorio del proyecto Gradle:

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

Los secretos son leidos por `publish.gradle.kts` desde variables de entorno proporcionadas por `MavenCentralPublisher.ps1`, y las propiedades Gradle requeridas, metadata del proyecto y variables de entorno se resuelven solo cuando se solicita una tarea de publicacion a Maven Central.

### Secretos

Los valores del publicador Maven Central se guardan mediante `DevSecretsManagerPs` usando estos nombres de secretos:

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

La raiz del proyecto consumidor debe contener `Project.json` con una propiedad `Project` que apunte a `gradlew.bat` o `gradlew`:

```json
{
  "Project": ".\\gradlew.bat"
}
```

Los valores relativos de `Project` se resuelven desde la raiz del proyecto consumidor, que es `../../` desde el directorio de la herramienta.

`SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS` es un array de strings con URLs directas HTTP/HTTPS de subida. Las URLs de subida por default son:

```text
http://keyserver.ubuntu.com:11371/pks/add
http://pgp.mit.edu:11371/pks/add
https://keys.openpgp.org/pks/add
```

## Validacion

`-Init`, `-List`, `-Edit`, `-Set`, `-UploadSigningPublicKey`, y `-Publish` inicializan y validan acceso a la herramienta hermana `DevSecretsManagerPs` antes de ejecutarse.

La lista de URLs de subida de servidores GPG se valida y repara cuando los secretos se inicializan o son accedidos por comandos relevantes:

- Valores null y strings vacios se eliminan.
- Hosts legacy se migran a URLs directas de subida.
- Las URLs de subida por default se aseguran.
- El valor final debe ser un array de strings no vacio con URLs absolutas HTTP/HTTPS de subida.

## Help

```powershell
.\MavenCentralPublisher.ps1 -Help
.\MavenCentralPublisher.ps1 -h
.\MavenCentralPublisher.ps1 -help
.\MavenCentralPublisher.ps1 -usage
```

Imprime el uso de comandos como texto plano capturable.

## Init

```powershell
.\MavenCentralPublisher.ps1 -Init
```

Inicializa `DevSecretsManagerPs` y crea los secretos faltantes del publicador Maven Central.

Tambien valida y repara `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS`.

Imprime progreso interactivo de `env.json`, el environment id, el archivo JSON de secrets del ambiente y los secrets del publicador Maven Central. No produce un resultado capturable.

## List

```powershell
.\MavenCentralPublisher.ps1 -List
```

Retorna el JSON completo de secrets despues de validar y reparar los valores del publicador Maven Central.

Este comando lee secretos locales. No lo ejecutes en logs o terminales compartidas donde los valores puedan exponerse.

## Edit

```powershell
.\MavenCentralPublisher.ps1 -Edit
.\MavenCentralPublisher.ps1 -Edit -Editor <EditorName>
```

Abre el archivo de secretos de `DevSecretsManagerPs` en un editor.

Antes de abrir el archivo, la herramienta valida y repara `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS`.

Retorna un objeto JSON con `Started` y `Editor`. `Editor` es el valor pasado a `-Editor`, o `null` cuando se usa el editor por default de `DevSecretsManagerPs`.

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

Actualiza solo los valores pasados explicitamente.

Retorna `true` cuando los valores proporcionados se guardan.

Flags soportados:

```text
-JavaExecutable
-SigningPrivateKey
-SigningPublicKey
-SigningPassword
-Username
-Password
-PublishingType
```

`-PublishingType` usa `ValidateSet` y acepta:

```text
automatic
user_managed
empty string
null
```

Los valores null se guardan como null. Los strings vacios se guardan como valores secretos vacios. `SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS` intencionalmente no se maneja con `-Set`.

`-SigningPrivateKey` y `-SigningPublicKey` aceptan contenido literal de la clave o un path a un archivo existente. Cuando el valor es un path valido, el contenido del archivo se guarda como valor del secreto.

## UploadSigningPublicKey

```powershell
.\MavenCentralPublisher.ps1 -UploadSigningPublicKey
.\MavenCentralPublisher.ps1 -UploadSigningPublicKey -File ".\public-key.asc"
```

Sube `SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY` a las URLs de subida de servidores GPG configuradas.

El comando usa las mismas reglas de resolucion de secretos que publish: las variables de entorno tienen prioridad sobre los secretos guardados cuando no son null ni vacias.

Cuando se proporciona `-File`, el contenido del archivo se usa como public key solo para esa subida. No actualiza el secreto guardado.

Cada URL configurada se intenta de forma independiente usando requests HTTP nativos de PowerShell. No se requiere ejecutable `gpg` ni herramienta externa de gestion de claves. El comando retorna un array JSON con resultados de subida y falla cuando alguna URL configurada no acepta la subida.

## Publish

```powershell
.\MavenCentralPublisher.ps1 -Publish
.\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand "..\MyJvmProject\gradlew.bat"
```

Publica un artefacto JVM en Sonatype Maven Central mediante el comando Gradle wrapper configurado en el archivo `Project.json` de la raiz del consumidor.

Por default, el script lee la propiedad `Project` de `Project.json`. Los valores relativos se resuelven desde la raiz del proyecto consumidor. El valor debe apuntar directamente a `gradlew.bat` en Windows o `gradlew` en sistemas Unix-like.

`-ProjectGradleCommand` es un override explicito opcional. Cuando se proporciona, debe apuntar directamente a `gradlew.bat` o `gradlew`.

La herramienta usa el directorio que contiene el Gradle wrapper resuelto como directorio del proyecto Gradle.

Durante publish, la herramienta:

- Valida secretos y variables de entorno.
- Repara la lista de URLs de subida de servidores GPG.
- Sube la public key de firma a las URLs configuradas usando requests HTTP nativos de PowerShell.
- Establece variables de entorno para Gradle usando los mismos nombres que los secretos.
- Establece `JAVA_HOME` desde `SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE`.
- Ejecuta `publishReleaseToCentralPortal` mediante el Gradle wrapper proporcionado.

Las variables de entorno tienen prioridad sobre los secretos guardados cuando no son null ni vacias.

Valores requeridos para publish:

```text
SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE
SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY
SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD
SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY
SONATYPE_MAVEN_CENTRAL_PASSWORD
SONATYPE_MAVEN_CENTRAL_USERNAME
```

`SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY` es requerida para publish y debe subirse correctamente a cada URL configurada de servidores GPG antes de ejecutar Gradle.

`SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE` usa `user_managed` por default cuando esta vacia.

El comando publish retorna un objeto JSON con `Published`, `GradleExitCode`, paths resueltos, resultados de subida de la public key y salida capturada de Gradle. Si Gradle falla, el comando retorna un objeto JSON de error y sale con codigo `1`.

## Version

```powershell
.\MavenCentralPublisher.ps1 -Version
.\MavenCentralPublisher.ps1 -v
```

Retorna la version del script como string JSON.

```text
"2.0.0"
```

## Flujo Recomendado

Instalar las herramientas requeridas en el proyecto consumidor:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
.\ProjectManager.ps1 -Tools Add -RepositoryName JvmMavenCentralPublisherPs -RepositoryUrl https://github.com/Satancito/JvmMavenCentralPublisherPs.git -Tag ""
```

Inicializar secretos del publicador:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Init
```

Configurar secretos:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -JavaExecutable "C:\Path\To\java.exe"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPrivateKey ".\private-key.asc"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPublicKey ".\public-key.asc"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -SigningPassword "<signing-password>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -Username "<sonatype-token-username>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -Password "<sonatype-token-password>"
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Set -PublishingType user_managed
```

Publicar con el Gradle wrapper del proyecto consumidor:

```powershell
.\Tools\JvmMavenCentralPublisherPs\MavenCentralPublisher.ps1 -Publish
```

## Seguridad

No commitear secretos reales, private keys, signing passwords, valores de token Sonatype, stores locales de secretos, caches Gradle, o output de build generado.

No ejecutar `-Publish` salvo que intencionalmente quieras publicar un artefacto en Maven Central.
