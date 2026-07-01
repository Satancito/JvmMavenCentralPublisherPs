[CmdletBinding(DefaultParameterSetName = "Help")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Init")]
    [switch]$Init,

    [Parameter(Mandatory = $true, ParameterSetName = "List")]
    [switch]$List,

    [Parameter(Mandatory = $true, ParameterSetName = "Edit")]
    [switch]$Edit,

    [Parameter(ParameterSetName = "Edit")]
    [ValidateNotNullOrEmpty()]
    [string]$Editor,

    [Parameter(Mandatory = $true, ParameterSetName = "Set")]
    [switch]$Set,

    [Parameter(Mandatory = $true, ParameterSetName = "Publish")]
    [switch]$Publish,

    [Parameter(Mandatory = $true, ParameterSetName = "UploadSigningPublicKey")]
    [switch]$UploadSigningPublicKey,

    [Parameter(ParameterSetName = "UploadSigningPublicKey")]
    [ValidateNotNullOrEmpty()]
    [string]$File,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$JavaExecutable,

    [Parameter(ParameterSetName = "Publish")]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectGradleCommand,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$SigningPrivateKey,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$SigningPublicKey,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$Username,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$Password,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [ValidateSet("automatic", "user_managed", "")]
    [object]$PublishingType,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$SigningPassword,

    [Parameter(ParameterSetName = "Help")]
    [Alias("h", "usage")]
    [switch]$Help,

    [Parameter(ParameterSetName = "Version")]
    [Alias("v")]
    [switch]$Version
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$ScriptVersion = "2.0.1"
$ProvidedParameterNames = @($PSBoundParameters.Keys)
$IsHelpRequest = $PSCmdlet.ParameterSetName -eq "Help"

$GpgKeyServersSecretName = "SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS"
$DefaultGpgKeyServers = @(
    "http://keyserver.ubuntu.com:11371/pks/add",
    "http://pgp.mit.edu:11371/pks/add",
    "https://keys.openpgp.org/pks/add"
)
$KeyServerUploadTimeoutSeconds = 30

$RequiredSecretNames = @(
    $GpgKeyServersSecretName,
    "SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE",
    "SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY",
    "SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD",
    "SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY",
    "SONATYPE_MAVEN_CENTRAL_PASSWORD",
    "SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE",
    "SONATYPE_MAVEN_CENTRAL_USERNAME"
)

function Show-Usage {
    $usage = @"
Maven Central Publisher

Usage:
  .\MavenCentralPublisher.ps1 -Init
  .\MavenCentralPublisher.ps1 -List
  .\MavenCentralPublisher.ps1 -Edit [-Editor <editor>]
  .\MavenCentralPublisher.ps1 -Set [-JavaExecutable <value>] [-SigningPrivateKey <value>] [-SigningPublicKey <value>] [-Username <value>] [-Password <value>] [-PublishingType <automatic|user_managed>] [-SigningPassword <value>]
  .\MavenCentralPublisher.ps1 -UploadSigningPublicKey [-File <path-to-public-key>]
  .\MavenCentralPublisher.ps1 -Publish [-ProjectGradleCommand <path-to-gradlew>]
  .\MavenCentralPublisher.ps1 -Help
  .\MavenCentralPublisher.ps1 -h
  .\MavenCentralPublisher.ps1 -help
  .\MavenCentralPublisher.ps1 -usage
  .\MavenCentralPublisher.ps1 -Usage
  .\MavenCentralPublisher.ps1 -Version
  .\MavenCentralPublisher.ps1 -version
  .\MavenCentralPublisher.ps1 -v

Modes:
  -Init
    Initializes DevSecretsManagerPs and creates these secrets when missing:
      SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS = [
        "http://keyserver.ubuntu.com:11371/pks/add",
        "http://pgp.mit.edu:11371/pks/add",
        "https://keys.openpgp.org/pks/add"
      ]
      SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE
      SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY
      SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD
      SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY
      SONATYPE_MAVEN_CENTRAL_PASSWORD
      SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE
      SONATYPE_MAVEN_CENTRAL_USERNAME
    Copies publish.gradle.kts from the tool directory to the consumer project root resolved as ../.. from this script when it is missing or different.
    When publish.gradle.kts is copied, stages and commits only that file in the consumer project Git repository.
    Prints initialization progress for env.json, guid.json, environment id, and Maven Central secret states.

  -List
    Returns JSON with only the Maven Central publisher secrets handled by this tool.

  -Edit
    Opens the DevSecretsManagerPs secrets file in an editor.
    Uses the default editor from SecretsManager.ps1 unless -Editor is provided.
    The GPG key server upload URLs value is validated and repaired before opening.
    Prints the launched editor information with non-capturable output and returns no pipeline value.

    Examples:
      .\MavenCentralPublisher.ps1 -Edit
      .\MavenCentralPublisher.ps1 -Edit -Editor code

  -Set
    Updates only the values explicitly provided.
    Null values are saved as null.
    Empty strings are saved as empty secret values.
    -PublishingType stores SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE as automatic, user_managed, or an empty value.
    -PublishingType accepts null, empty, automatic, or user_managed.
    -SigningPrivateKey and -SigningPublicKey accept either literal key content or a path to an existing key file.
    GPG key server upload URLs are intentionally not handled by -Set yet.

    Examples:
      .\MavenCentralPublisher.ps1 -Set -JavaExecutable "C:\Program Files\Eclipse Adoptium\jdk-17\bin\java.exe"
      .\MavenCentralPublisher.ps1 -Set -SigningPrivateKey "<private-key>"
      .\MavenCentralPublisher.ps1 -Set -SigningPrivateKey ".\private-key.asc"
      .\MavenCentralPublisher.ps1 -Set -SigningPublicKey "<public-key>"
      .\MavenCentralPublisher.ps1 -Set -SigningPublicKey ".\public-key.asc"
      .\MavenCentralPublisher.ps1 -Set -Username "<sonatype-token-username>"
      .\MavenCentralPublisher.ps1 -Set -Password "<sonatype-token-password>"
      .\MavenCentralPublisher.ps1 -Set -PublishingType automatic
      .\MavenCentralPublisher.ps1 -Set -PublishingType user_managed
      .\MavenCentralPublisher.ps1 -Set -SigningPassword "<signing-password>"
      .\MavenCentralPublisher.ps1 -Set -Password ""

  -Publish
    Publishes a JVM artifact to Sonatype Maven Central using Gradle.
    By default, the Gradle wrapper command is read from the Project property in the consumer root Project.json file.
    Relative Project values are resolved from the consumer project root.
    -ProjectGradleCommand can be used as an explicit override.
    Environment variables have priority over secrets when they are not null or empty.
    Every Maven Central publisher value must resolve to a non-empty value:
      SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE
      SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY
      SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD
      SONATYPE_MAVEN_CENTRAL_PASSWORD
      SONATYPE_MAVEN_CENTRAL_USERNAME
    SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE defaults to user_managed when empty.
    SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS is validated and repaired as upload URLs before publishing.
    SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY is required and must upload successfully to every configured upload URL before publishing.

    Examples:
      .\MavenCentralPublisher.ps1 -Publish
      .\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand "..\MyJvmProject\gradlew.bat"
      .\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand "../MyJvmProject/gradlew"

  -UploadSigningPublicKey
    Uploads SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY to the configured GPG key server upload URLs.
    Environment variables have priority over secrets when they are not null or empty.
    When -File is provided, that file content is used as the public key for this upload only.
    Each upload URL is attempted and reported independently.
    The command fails when any configured upload URL does not accept the upload.

    Example:
      .\MavenCentralPublisher.ps1 -UploadSigningPublicKey
      .\MavenCentralPublisher.ps1 -UploadSigningPublicKey -File ".\public-key.asc"

  -Version
    Returns the script version as a JSON string.
"@

    return $usage
}

function Show-Version {
    return $ScriptVersion
}

function Write-JsonOutput {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        Write-Output "null"
        return
    }

    Write-Output ($Value | ConvertTo-Json -Depth 100)
}

function Resolve-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue

    if ($resolved) {
        return $resolved.Path
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Resolve-SecretsManagerPath {
    $resolvedPath = Resolve-FullPath -Path "..\DevSecretsManagerPs\SecretsManager.ps1"

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "SecretsManager.ps1 was not found: $resolvedPath"
    }

    return $resolvedPath
}

function Get-SecretsManagerDirectory {
    return Split-Path -Path (Resolve-SecretsManagerPath) -Parent
}

function Get-SecretsManagerEnvFilePath {
    return Join-Path -Path (Get-SecretsManagerDirectory) -ChildPath "env.json"
}

function Get-SecretsManagerSecretsDirectory {
    $homeDirectory = $HOME
    if ([string]::IsNullOrWhiteSpace($homeDirectory)) {
        $homeDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    }

    return Join-Path -Path $homeDirectory -ChildPath ".devsecretsmanager"
}

function Get-SecretsManagerSecretsFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    return Join-Path -Path (Get-SecretsManagerSecretsDirectory) -ChildPath "$Id.json"
}

function Invoke-SecretsManager {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )

    $managerPath = Resolve-SecretsManagerPath
    & $managerPath @Parameters 6>$null

    if (-not $?) {
        throw "SecretsManager.ps1 failed."
    }
}

function ConvertFrom-JsonLines {
    param(
        [AllowNull()]
        [object]$JsonLines
    )

    $json = ($JsonLines | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($json)) {
        return $null
    }

    return ConvertFrom-Json -InputObject $json -ErrorAction Stop
}

function Get-SecretsJson {
    $jsonLines = Invoke-SecretsManager -Parameters @{ List = $true }
    $json = ($jsonLines | Out-String).Trim()

    if ([string]::IsNullOrWhiteSpace($json)) {
        return [ordered]@{}
    }

    $values = [ordered]@{}
    $parsed = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    foreach ($property in $parsed.PSObject.Properties) {
        $values[$property.Name] = $property.Value
    }

    return $values
}

function Read-TextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.File]::ReadAllText($Path)
}

function Read-JsonObjectAsOrderedHashtable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $json = Read-TextFile -Path $Path
    $values = [ordered]@{}

    if ([string]::IsNullOrWhiteSpace($json)) {
        return $values
    }

    $parsed = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    foreach ($property in $parsed.PSObject.Properties) {
        $values[$property.Name] = $property.Value
    }

    return $values
}

function Get-JsonObjectFileStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return "Created"
    }

    try {
        $json = Read-TextFile -Path $Path
        if ([string]::IsNullOrWhiteSpace($json)) {
            return "Regenerated"
        }

        $parsed = ConvertFrom-Json -InputObject $json -ErrorAction Stop
        if ($parsed -isnot [PSCustomObject]) {
            return "Regenerated"
        }

        return "Existing"
    }
    catch {
        return "Regenerated"
    }
}

function Get-SecretsManagerEnvironmentStateBeforeInit {
    $envFilePath = Get-SecretsManagerEnvFilePath
    $envFileStatus = Get-JsonObjectFileStatus -Path $envFilePath
    $id = $null

    if ($envFileStatus -eq "Existing") {
        $envValues = Read-JsonObjectAsOrderedHashtable -Path $envFilePath
        $existingId = [string]$envValues["Id"]

        if ([string]::IsNullOrWhiteSpace($existingId)) {
            $envFileStatus = "IdAdded"
        }
        else {
            $parsedGuid = [Guid]::Empty
            if ([Guid]::TryParse($existingId, [ref]$parsedGuid)) {
                $id = $parsedGuid.ToString()
            }
            else {
                $envFileStatus = "Regenerated"
            }
        }
    }

    $secretsFilePath = if ($null -ne $id) { Get-SecretsManagerSecretsFilePath -Id $id } else { $null }
    $secretsFileStatus = if ($null -ne $secretsFilePath) { Get-JsonObjectFileStatus -Path $secretsFilePath } else { "Created" }

    return [PSCustomObject]@{
        EnvFilePath = $envFilePath
        EnvFileStatus = $envFileStatus
        Id = $id
        SecretsFilePath = $secretsFilePath
        SecretsFileStatus = $secretsFileStatus
    }
}

function Show-MavenCentralSecrets {
    Repair-MavenCentralSecrets | Out-Null
    $secrets = Get-SecretsJson
    $mavenCentralSecrets = [ordered]@{}

    foreach ($secretName in $RequiredSecretNames) {
        $mavenCentralSecrets[$secretName] = if ($secrets.Contains($secretName)) { $secrets[$secretName] } else { $null }
    }

    return $mavenCentralSecrets
}

function Edit-MavenCentralSecrets {
    Repair-MavenCentralSecrets | Out-Null

    $editParameters = @{ Edit = $true }
    if (-not [string]::IsNullOrWhiteSpace($Editor)) {
        $editParameters["Editor"] = $Editor
        Write-Host "Launching editor: $Editor"
    }
    else {
        Write-Host "Launching default editor from DevSecretsManagerPs."
    }

    Invoke-SecretsManager -Parameters $editParameters | Out-Null
}

function Set-ConfiguredSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value
    )

    $parameters = @{
        Add = $Name
        Force = $true
    }

    if ($null -ne $Value) {
        $parameters["Value"] = [string]$Value
    }

    Invoke-SecretsManager -Parameters $parameters | Out-Null
}

function Resolve-FileBackedSecretValue {
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    if ($null -eq $Value -or $Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    $rawValue = [string]$Value
    if ($rawValue.Contains("`n") -or
        $rawValue.Contains("`r") -or
        $rawValue.TrimStart().StartsWith("-----BEGIN ")) {
        return $Value
    }

    $candidatePath = $rawValue.Trim()
    if (($candidatePath.StartsWith('"') -and $candidatePath.EndsWith('"')) -or
        ($candidatePath.StartsWith("'") -and $candidatePath.EndsWith("'"))) {
        $candidatePath = $candidatePath.Substring(1, $candidatePath.Length - 2)
    }

    $candidatePath = [Environment]::ExpandEnvironmentVariables($candidatePath)
    $resolvedPath = Resolve-Path -LiteralPath $candidatePath -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($null -ne $resolvedPath -and (Test-Path -LiteralPath $resolvedPath.ProviderPath -PathType Leaf)) {
        return Read-TextFile -Path $resolvedPath.ProviderPath
    }

    $looksLikePath = $candidatePath -match '[\\/]' -or
        $candidatePath -match '^[A-Za-z]:' -or
        [System.IO.Path]::GetExtension($candidatePath) -ne [string]::Empty

    if (-not $looksLikePath) {
        return $Value
    }

    throw "$ParameterName looks like a file path, but the file was not found or is not readable: $candidatePath"
}

function Set-MavenCentralSecrets {
    Repair-MavenCentralSecrets | Out-Null

    $updates = [ordered]@{}
    $setParameterNames = @(
        "JavaExecutable",
        "SigningPrivateKey",
        "SigningPublicKey",
        "Username",
        "Password",
        "PublishingType",
        "SigningPassword"
    ) | Where-Object { $ProvidedParameterNames -contains $_ }

    if ($ProvidedParameterNames -contains "JavaExecutable") {
        $updates["SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE"] = $JavaExecutable
    }

    if ($ProvidedParameterNames -contains "SigningPrivateKey") {
        $updates["SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY"] = Resolve-FileBackedSecretValue -Value $SigningPrivateKey -ParameterName "-SigningPrivateKey"
    }

    if ($ProvidedParameterNames -contains "SigningPublicKey") {
        $updates["SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY"] = Resolve-FileBackedSecretValue -Value $SigningPublicKey -ParameterName "-SigningPublicKey"
    }

    if ($ProvidedParameterNames -contains "Username") {
        $updates["SONATYPE_MAVEN_CENTRAL_USERNAME"] = $Username
    }

    if ($ProvidedParameterNames -contains "Password") {
        $updates["SONATYPE_MAVEN_CENTRAL_PASSWORD"] = $Password
    }

    if ($ProvidedParameterNames -contains "PublishingType") {
        $updates["SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE"] = $PublishingType
    }

    if ($ProvidedParameterNames -contains "SigningPassword") {
        $updates["SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD"] = $SigningPassword
    }

    if ($setParameterNames.Count -eq 0) {
        throw "Use -Set with at least one value: -JavaExecutable, -SigningPrivateKey, -SigningPublicKey, -Username, -Password, -PublishingType, or -SigningPassword."
    }

    if ($updates.Count -eq 0) {
        return $false
    }

    foreach ($entry in $updates.GetEnumerator()) {
        Set-ConfiguredSecret -Name $entry.Key -Value $entry.Value
    }

    return $true
}

function Get-EnvironmentConfiguredValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")

    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return [string]$value
}

function Get-ResolvedConfiguredValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Secrets,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $environmentValue = Get-EnvironmentConfiguredValue -Name $Name
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        return $environmentValue
    }

    if (-not $Secrets.Contains($Name)) {
        return $null
    }

    $value = $Secrets[$Name]
    if ($null -eq $value) {
        return $null
    }

    return [string]$value
}

function Get-RequiredResolvedConfiguredValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Secrets,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-ResolvedConfiguredValue -Secrets $Secrets -Name $Name
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required value '$Name' is missing, null, or empty. Configure it in an environment variable or secret before running this command."
    }

    return $value
}

function ConvertTo-GpgKeyServersFromText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return @(
        $Value -split "[,\r\n;]" |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-ResolvedGpgKeyServers {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Secrets
    )

    $environmentValue = Get-EnvironmentConfiguredValue -Name $GpgKeyServersSecretName
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        return ConvertTo-NormalizedGpgKeyServers -Value (ConvertTo-GpgKeyServersFromText -Value $environmentValue)
    }

    if (-not $Secrets.Contains($GpgKeyServersSecretName)) {
        return ConvertTo-NormalizedGpgKeyServers -Value $null
    }

    return ConvertTo-NormalizedGpgKeyServers -Value $Secrets[$GpgKeyServersSecretName]
}

function Resolve-JavaExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JavaExecutable
    )

    $resolvedPath = Resolve-FullPath -Path $JavaExecutable
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Java executable was not found: $resolvedPath"
    }

    return $resolvedPath
}

function Get-JavaHomeFromExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JavaExecutablePath
    )

    $binDirectory = Split-Path -Path $JavaExecutablePath -Parent
    if ((Split-Path -Path $binDirectory -Leaf) -ne "bin") {
        throw "Java executable must be inside a bin directory: $JavaExecutablePath"
    }

    $javaHome = Split-Path -Path $binDirectory -Parent
    if (-not (Test-Path -LiteralPath $javaHome -PathType Container)) {
        throw "Could not resolve JAVA_HOME from java executable: $JavaExecutablePath"
    }

    return $javaHome
}

function Resolve-ProjectGradleCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectGradleCommand
    )

    $resolvedPath = Resolve-FullPath -Path $ProjectGradleCommand
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Project Gradle command was not found: $resolvedPath"
    }

    $commandName = Split-Path -Path $resolvedPath -Leaf
    if ($commandName -notin @("gradlew", "gradlew.bat")) {
        throw "Project Gradle command must be gradlew or gradlew.bat. Current command: $resolvedPath"
    }

    return $resolvedPath
}

function Get-ScriptDirectory {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    return Split-Path -Path $MyInvocation.MyCommand.Path -Parent
}

function Get-ConsumerProjectRoot {
    $scriptDirectory = Get-ScriptDirectory
    return [System.IO.Path]::GetFullPath((Join-Path -Path $scriptDirectory -ChildPath "..\.."))
}

function Copy-PublishGradleScriptToConsumerRoot {
    $scriptDirectory = Get-ScriptDirectory
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path -Path $scriptDirectory -ChildPath "publish.gradle.kts"))
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "publish.gradle.kts was not found next to MavenCentralPublisher.ps1: $sourcePath"
    }

    $consumerRoot = Get-ConsumerProjectRoot
    if (-not (Test-Path -LiteralPath $consumerRoot -PathType Container)) {
        throw "Consumer project root was not found: $consumerRoot"
    }

    $destinationPath = [System.IO.Path]::GetFullPath((Join-Path -Path $consumerRoot -ChildPath "publish.gradle.kts"))
    $status = "Created"

    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
        if ($sourceHash -eq $destinationHash) {
            $status = "Existing"
        }
        else {
            $status = "Updated"
        }
    }

    if ($status -ne "Existing") {
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    }

    return [PSCustomObject]@{
        Source = $sourcePath
        Destination = $destinationPath
        Status = $status
        ConsumerRoot = $consumerRoot
    }
}

function Invoke-PublishGradleScriptGitCommit {
    param(
        [Parameter(Mandatory = $true)]
        [object]$CopyState
    )

    if ($CopyState.Status -eq "Existing") {
        return [PSCustomObject]@{
            Staged = $false
            Committed = $false
            Commit = $null
            Message = "publish.gradle.kts was unchanged."
        }
    }

    $consumerRoot = [string]$CopyState.ConsumerRoot
    $insideWorkTree = & git -C $consumerRoot rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]$insideWorkTree -ne "true") {
        throw "Consumer project root is not a Git work tree: $consumerRoot"
    }

    $gitAddOutput = & git -C $consumerRoot add -- "publish.gradle.kts" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Could not stage copied publish.gradle.kts in consumer project root: $consumerRoot $gitAddOutput"
    }

    $gitDiffOutput = & git -C $consumerRoot diff --cached --quiet -- "publish.gradle.kts" 2>&1
    if ($LASTEXITCODE -eq 0) {
        return [PSCustomObject]@{
            Staged = $true
            Committed = $false
            Commit = $null
            Message = "publish.gradle.kts was staged but had no indexed changes."
        }
    }
    elseif ($LASTEXITCODE -ne 1) {
        throw "Could not inspect staged publish.gradle.kts changes in consumer project root: $consumerRoot $gitDiffOutput"
    }

    $commitMessage = "chore: update Maven Central publish script"
    $gitCommitOutput = & git -C $consumerRoot commit --only -m $commitMessage -- "publish.gradle.kts" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Could not commit copied publish.gradle.kts in consumer project root: $consumerRoot $gitCommitOutput"
    }

    $commitHash = & git -C $consumerRoot rev-parse --short HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "Could not read consumer project commit hash after committing publish.gradle.kts."
    }

    return [PSCustomObject]@{
        Staged = $true
        Committed = $true
        Commit = [string]$commitHash
        Message = $commitMessage
    }
}

function Get-ConsumerProjectJsonPath {
    $consumerRoot = Get-ConsumerProjectRoot
    return [System.IO.Path]::GetFullPath((Join-Path -Path $consumerRoot -ChildPath "Project.json"))
}

function Get-ProjectGradleCommandFromProjectJson {
    $projectJsonPath = Get-ConsumerProjectJsonPath
    if (-not (Test-Path -LiteralPath $projectJsonPath -PathType Leaf)) {
        throw "Project.json was not found in the consumer project root: $projectJsonPath"
    }

    $projectValues = Read-JsonObjectAsOrderedHashtable -Path $projectJsonPath
    if (-not $projectValues.Contains("Project")) {
        throw "Project.json must contain a Project property with the path to gradlew or gradlew.bat: $projectJsonPath"
    }

    $projectValue = [string]$projectValues["Project"]
    if ([string]::IsNullOrWhiteSpace($projectValue)) {
        throw "Project.json Project property must not be null or empty: $projectJsonPath"
    }

    if ([System.IO.Path]::IsPathRooted($projectValue)) {
        return Resolve-ProjectGradleCommand -ProjectGradleCommand $projectValue
    }

    $consumerRoot = Get-ConsumerProjectRoot
    $projectGradleCommand = Join-Path -Path $consumerRoot -ChildPath $projectValue
    return Resolve-ProjectGradleCommand -ProjectGradleCommand $projectGradleCommand
}

function Resolve-EffectiveProjectGradleCommand {
    if ($ProvidedParameterNames -contains "ProjectGradleCommand") {
        return Resolve-ProjectGradleCommand -ProjectGradleCommand $ProjectGradleCommand
    }

    return Get-ProjectGradleCommandFromProjectJson
}

function Get-HttpErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ErrorRecord
    )

    $response = $ErrorRecord.Exception.Response
    if ($null -ne $response) {
        $statusCode = try { [int]$response.StatusCode } catch { $null }
        $statusDescription = try { [string]$response.StatusDescription } catch { "" }
        if ($null -ne $statusCode) {
            return "HTTP $statusCode $statusDescription".Trim()
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.Exception.Message)) {
        return $ErrorRecord.Exception.Message
    }

    return [string]$ErrorRecord
}

function Invoke-KeyServerHttpUpload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UploadUrl,

        [Parameter(Mandatory = $true)]
        [string]$SigningPublicKey
    )

    $response = Invoke-WebRequest -Uri $UploadUrl -Method Post -Body @{ keytext = $SigningPublicKey } -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -TimeoutSec $KeyServerUploadTimeoutSeconds -ErrorAction Stop
    return [PSCustomObject]@{
        Uri = $UploadUrl
        StatusCode = [int]$response.StatusCode
        Message = "Upload request accepted."
    }
}

function Resolve-GpgKeyServerUploadUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $trimmedValue = $Value.Trim()
    switch ($trimmedValue.ToLowerInvariant()) {
        "keyserver.ubuntu.com" { return "http://keyserver.ubuntu.com:11371/pks/add" }
        "pgp.mit.edu" { return "http://pgp.mit.edu:11371/pks/add" }
        "keys.openpgp.org" { return "https://keys.openpgp.org/pks/add" }
    }

    $uri = $null
    if (-not [System.Uri]::TryCreate($trimmedValue, [System.UriKind]::Absolute, [ref]$uri)) {
        throw "$GpgKeyServersSecretName values must be absolute upload URLs. Current value: $Value"
    }

    if ($uri.Scheme -notin @("http", "https")) {
        throw "$GpgKeyServersSecretName upload URLs must use http or https. Current value: $Value"
    }

    return $uri.AbsoluteUri
}

function Invoke-PublicKeyServerUpload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SigningPublicKey,

        [Parameter(Mandatory = $true)]
        [string[]]$KeyServers
    )

    $results = @()

    foreach ($keyServerUploadUrl in $KeyServers) {
        try {
            $uploadResult = Invoke-KeyServerHttpUpload -UploadUrl $keyServerUploadUrl -SigningPublicKey $SigningPublicKey
            $results += [PSCustomObject]@{
                UploadUrl = $keyServerUploadUrl
                Uploaded = $true
                StatusCode = $uploadResult.StatusCode
                Uri = $uploadResult.Uri
                Message = $uploadResult.Message
            }
        }
        catch {
            $results += [PSCustomObject]@{
                UploadUrl = $keyServerUploadUrl
                Uploaded = $false
                StatusCode = $null
                Uri = ""
                Message = Get-HttpErrorMessage -ErrorRecord $_
            }
        }
    }

    return $results
}

function Test-PublicKeyUploadResults {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Results
    )

    $failedResults = @($Results | Where-Object { -not $_.Uploaded })
    if ($failedResults.Count -gt 0) {
        $summary = ($failedResults | ForEach-Object { "$($_.UploadUrl): $($_.Message)" }) -join [Environment]::NewLine
        throw "The signing public key could not be uploaded to every configured GPG key server upload URL. Failed uploads: $summary"
    }
}

function Publish-MavenCentralPublicKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SigningPublicKey,

        [Parameter(Mandatory = $true)]
        [string[]]$KeyServers
    )

    $results = Invoke-PublicKeyServerUpload -SigningPublicKey $SigningPublicKey -KeyServers $KeyServers
    Test-PublicKeyUploadResults -Results $results
    return $results
}

function Invoke-MavenCentralPublish {
    Repair-MavenCentralSecrets | Out-Null
    $secrets = Get-SecretsJson

    $resolvedProjectGradleCommand = Resolve-EffectiveProjectGradleCommand
    $resolvedProjectDirectory = Split-Path -Path $resolvedProjectGradleCommand -Parent
    $javaExecutable = Resolve-JavaExecutable -JavaExecutable (Get-RequiredResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE")
    $javaHome = Get-JavaHomeFromExecutable -JavaExecutablePath $javaExecutable
    $signingPrivateKey = Get-RequiredResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY"
    $signingPassword = Get-RequiredResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD"
    $signingPublicKey = Get-RequiredResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY"
    $sonatypeUsername = Get-RequiredResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_USERNAME"
    $sonatypePassword = Get-RequiredResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_PASSWORD"
    $publishingType = Get-ResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE"

    if ([string]::IsNullOrWhiteSpace($publishingType)) {
        $publishingType = "user_managed"
    }

    if ($publishingType -notin @("user_managed", "automatic")) {
        throw "SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE must be user_managed or automatic. Current value: $publishingType"
    }

    $keyServers = @(Get-ResolvedGpgKeyServers -Secrets $secrets)
    if ($keyServers.Count -eq 0) {
        throw "$GpgKeyServersSecretName must contain at least one key server."
    }

    $publicKeyUploadResults = @(Publish-MavenCentralPublicKey -SigningPublicKey $signingPublicKey -KeyServers $keyServers)

    $env:SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS = $keyServers -join ";"
    $env:SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE = $javaExecutable
    $env:SONATYPE_MAVEN_CENTRAL_SIGNING_PRIVATE_KEY = $signingPrivateKey
    $env:SONATYPE_MAVEN_CENTRAL_SIGNING_PASSWORD = $signingPassword
    $env:SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY = $signingPublicKey
    $env:SONATYPE_MAVEN_CENTRAL_USERNAME = $sonatypeUsername
    $env:SONATYPE_MAVEN_CENTRAL_PASSWORD = $sonatypePassword
    $env:SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE = $publishingType
    $env:JAVA_HOME = $javaHome
    $env:Path = "$javaHome\bin;$env:Path"

    $gradleOutput = @()
    $gradleExitCode = 0
    Push-Location -LiteralPath $resolvedProjectDirectory
    try {
        $gradleOutput = @(& $resolvedProjectGradleCommand "publishReleaseToCentralPortal" "--stacktrace" 2>&1)
        $gradleExitCode = $LASTEXITCODE
        if ($gradleExitCode -ne 0) {
            $gradleOutputText = ($gradleOutput | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
            throw "Gradle publish failed with exit code $gradleExitCode. Output: $gradleOutputText"
        }
    }
    finally {
        Pop-Location
    }

    return [PSCustomObject]@{
        Published = $true
        GradleExitCode = $gradleExitCode
        ProjectDirectory = $resolvedProjectDirectory
        ProjectGradleCommand = $resolvedProjectGradleCommand
        JavaHome = $javaHome
        PublishingType = $publishingType
        PublicKeyUploadResults = $publicKeyUploadResults
        GradleOutput = @($gradleOutput | ForEach-Object { [string]$_ })
    }
}

function Invoke-SigningPublicKeyUpload {
    Repair-MavenCentralSecrets | Out-Null
    $secrets = Get-SecretsJson

    if ($ProvidedParameterNames -contains "File") {
        $resolvedFilePath = Resolve-FullPath -Path $File
        if (-not (Test-Path -LiteralPath $resolvedFilePath -PathType Leaf)) {
            throw "Signing public key file was not found: $resolvedFilePath"
        }

        $signingPublicKey = Read-TextFile -Path $resolvedFilePath
        if ([string]::IsNullOrWhiteSpace($signingPublicKey)) {
            throw "Signing public key file is empty: $resolvedFilePath"
        }
    }
    else {
        $signingPublicKey = Get-RequiredResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY"
    }

    $keyServers = @(Get-ResolvedGpgKeyServers -Secrets $secrets)
    if ($keyServers.Count -eq 0) {
        throw "$GpgKeyServersSecretName must contain at least one key server."
    }

    return @(Publish-MavenCentralPublicKey -SigningPublicKey $signingPublicKey -KeyServers $keyServers)
}

function Write-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Value
    )

    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function ConvertTo-NormalizedGpgKeyServers {
    param(
        [object]$Value
    )

    $normalized = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($null -ne $Value -and $Value -isnot [string] -and $Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            if ($item -isnot [string]) {
                continue
            }

            $server = $item.Trim()
            if ([string]::IsNullOrWhiteSpace($server)) {
                continue
            }

            $uploadUrl = Resolve-GpgKeyServerUploadUrl -Value $server
            if ($seen.Add($uploadUrl)) {
                $normalized.Add($uploadUrl)
            }
        }
    }

    foreach ($defaultServer in $DefaultGpgKeyServers) {
        $uploadUrl = Resolve-GpgKeyServerUploadUrl -Value $defaultServer
        if ($seen.Add($uploadUrl)) {
            $normalized.Add($uploadUrl)
        }
    }

    return $normalized.ToArray()
}

function Repair-GpgKeyServers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SecretsFilePath
    )

    $secrets = Read-JsonObjectAsOrderedHashtable -Path $SecretsFilePath
    $hasSecret = $secrets.Contains($GpgKeyServersSecretName)
    $currentValue = if ($hasSecret) { $secrets[$GpgKeyServersSecretName] } else { $null }
    $normalizedValue = ConvertTo-NormalizedGpgKeyServers -Value $currentValue
    $currentText = if ($null -eq $currentValue -or $currentValue -is [string] -or $currentValue -isnot [System.Collections.IEnumerable]) {
        $null
    }
    else {
        @($currentValue) -join "`n"
    }
    $normalizedText = $normalizedValue -join "`n"

    if ($hasSecret -and $currentText -eq $normalizedText) {
        return "Existing"
    }

    $secrets[$GpgKeyServersSecretName] = $normalizedValue
    Write-JsonObject -Path $SecretsFilePath -Value $secrets

    if ($hasSecret) {
        return "Repaired"
    }

    return "Created"
}

function Repair-MavenCentralSecrets {
    $secretsFilePath = ConvertFrom-JsonLines -JsonLines (Invoke-SecretsManager -Parameters @{ Init = $true } | Select-Object -Last 1)
    if ([string]::IsNullOrWhiteSpace($secretsFilePath)) {
        throw "SecretsManager.ps1 did not return the secrets file path."
    }

    return [PSCustomObject]@{
        SecretsFilePath = $secretsFilePath
        GpgKeyServersState = Repair-GpgKeyServers -SecretsFilePath $secretsFilePath
    }
}

function Initialize-MavenCentralSecrets {
    $environmentStateBeforeInit = Get-SecretsManagerEnvironmentStateBeforeInit
    $publishGradleScriptState = Copy-PublishGradleScriptToConsumerRoot
    $publishGradleGitState = Invoke-PublishGradleScriptGitCommit -CopyState $publishGradleScriptState
    $repairResult = Repair-MavenCentralSecrets
    $secretStates = [ordered]@{}
    $secretStates[$GpgKeyServersSecretName] = $repairResult.GpgKeyServersState

    foreach ($secretName in $RequiredSecretNames) {
        if ($secretName -eq $GpgKeyServersSecretName) {
            continue
        }

        $created = ConvertFrom-JsonLines -JsonLines (Invoke-SecretsManager -Parameters @{ Add = $secretName })
        $secretStates[$secretName] = if ($created) { "Created" } else { "Existing" }
    }

    $secretsFileStatus = $environmentStateBeforeInit.SecretsFileStatus
    if ($null -ne $environmentStateBeforeInit.SecretsFilePath -and
        $environmentStateBeforeInit.SecretsFilePath -ne $repairResult.SecretsFilePath) {
        $secretsFileStatus = "Created"
    }

    Write-Host "Maven Central publisher initialization"
    Write-Host "env.json: $($environmentStateBeforeInit.EnvFilePath) [$($environmentStateBeforeInit.EnvFileStatus)]"

    if ($environmentStateBeforeInit.EnvFileStatus -eq "Created") {
        Write-Host "env.json was created."
    }
    elseif ($environmentStateBeforeInit.EnvFileStatus -in @("Regenerated", "IdAdded")) {
        Write-Host "env.json was corrected."
    }

    if ($environmentStateBeforeInit.EnvFileStatus -in @("Created", "Regenerated", "IdAdded")) {
        Write-Host "A new environment id was created or assigned."
    }

    Write-Host "publish.gradle.kts: $($publishGradleScriptState.Destination) [$($publishGradleScriptState.Status)]"
    if ($publishGradleScriptState.Status -eq "Created") {
        Write-Host "publish.gradle.kts was copied to the consumer project root."
    }
    elseif ($publishGradleScriptState.Status -eq "Updated") {
        Write-Host "publish.gradle.kts was updated in the consumer project root."
    }

    if ($publishGradleGitState.Committed) {
        Write-Host "publish.gradle.kts was staged and committed in the consumer project root."
        Write-Host "Consumer project commit: $($publishGradleGitState.Commit)"
    }
    elseif ($publishGradleGitState.Staged) {
        Write-Host "publish.gradle.kts was staged but no commit was created."
    }
    else {
        Write-Host "publish.gradle.kts was not staged because it was unchanged."
    }

    Write-Host "guid.json: $($repairResult.SecretsFilePath) [$secretsFileStatus]"
    if ($secretsFileStatus -eq "Created") {
        Write-Host "guid.json was created."
    }
    elseif ($secretsFileStatus -eq "Regenerated") {
        Write-Host "guid.json was corrected."
    }

    Write-Host "Maven Central publisher secrets:"
    foreach ($secretName in $secretStates.Keys) {
        Write-Host "  $secretName [$($secretStates[$secretName])]"
    }
}

function Invoke-Main {
    if ($IsHelpRequest) {
        return Show-Usage
    }

    if ($Init) {
        Initialize-MavenCentralSecrets
        return
    }

    if ($List) {
        return Show-MavenCentralSecrets
    }

    if ($Edit) {
        Edit-MavenCentralSecrets
        return
    }

    if ($Set) {
        return Set-MavenCentralSecrets
    }

    if ($Publish) {
        return Invoke-MavenCentralPublish
    }

    if ($UploadSigningPublicKey) {
        return Invoke-SigningPublicKeyUpload
    }

    if ($Version) {
        return Show-Version
    }

    return Show-Usage
}

try {
    $result = Invoke-Main
    if ($IsHelpRequest) {
        Write-Output $result
        return
    }

    if ($Init) {
        return
    }

    if ($Edit) {
        return
    }

    Write-JsonOutput -Value $result
}
catch {
    Write-JsonOutput -Value ([ordered]@{
        Success = $false
        Error = Get-HttpErrorMessage -ErrorRecord $_
    })
    exit 1
}
