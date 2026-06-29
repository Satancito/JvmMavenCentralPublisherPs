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

    [Parameter(Mandatory = $true, ParameterSetName = "Publish")]
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
$ScriptVersion = "0.4.0"
$ProvidedParameterNames = @($PSBoundParameters.Keys)

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
  .\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand <path-to-gradlew>
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

  -List
    Lists only the Maven Central publisher secrets in table format.

  -Edit
    Opens the DevSecretsManagerPs secrets file in an editor.
    Uses the default editor from SecretsManager.ps1 unless -Editor is provided.
    The GPG key server upload URLs value is validated and repaired before opening.

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
    Prints the script version.
"@

    Write-Host $usage
}

function Show-Version {
    Write-Output $ScriptVersion
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

function Get-SecretsJson {
    $jsonLines = Invoke-SecretsManager -Parameters @{ Json = $true }
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

function Read-JsonObjectAsOrderedHashtable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $json = Get-Content -LiteralPath $Path -Raw
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

function Convert-SecretValueToText {
    param(
        [object]$Value
    )

    if ($null -eq $Value) {
        return "null"
    }

    if ($Value -is [array]) {
        return $Value -join ", "
    }

    if ([string]::Empty -eq [string]$Value) {
        return "empty"
    }

    return [string]$Value
}

function Write-MavenCentralSecretsTable {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Rows
    )

    $nameHeader = "Name"
    $valueHeader = "Value"
    $nameWidth = $nameHeader.Length
    $valueWidth = $valueHeader.Length

    foreach ($row in $Rows) {
        $nameWidth = [Math]::Max($nameWidth, ([string]$row.Name).Length)
        $valueWidth = [Math]::Max($valueWidth, (Convert-SecretValueToText -Value $row.Value).Length)
    }

    Write-Host $nameHeader.PadRight($nameWidth) -ForegroundColor Magenta -NoNewline
    Write-Host "  " -NoNewline
    Write-Host $valueHeader.PadRight($valueWidth) -ForegroundColor Magenta
    Write-Host ("-" * $nameWidth) -NoNewline
    Write-Host "  " -NoNewline
    Write-Host ("-" * $valueWidth)

    foreach ($row in $Rows) {
        $valueText = Convert-SecretValueToText -Value $row.Value
        Write-Host ([string]$row.Name).PadRight($nameWidth) -ForegroundColor Blue -NoNewline
        Write-Host "  " -NoNewline

        if ($null -eq $row.Value -or [string]::Empty -eq [string]$row.Value) {
            Write-Host $valueText.PadRight($valueWidth) -ForegroundColor Cyan
        }
        else {
            Write-Host $valueText.PadRight($valueWidth)
        }
    }
}

function Show-MavenCentralSecrets {
    Repair-MavenCentralSecrets | Out-Null
    $secrets = Get-SecretsJson
    $rows = foreach ($secretName in $RequiredSecretNames) {
        [PSCustomObject]@{
            Name = $secretName
            Value = if ($secrets.Contains($secretName)) { $secrets[$secretName] } else { $null }
        }
    }

    Write-MavenCentralSecretsTable -Rows @($rows)
}

function Edit-MavenCentralSecrets {
    Repair-MavenCentralSecrets | Out-Null

    $editParameters = @{ Edit = $true }
    if (-not [string]::IsNullOrWhiteSpace($Editor)) {
        $editParameters["Editor"] = $Editor
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
        return Get-Content -LiteralPath $resolvedPath.ProviderPath -Raw
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
        Write-Host "No Maven Central publisher secrets updated."
        return
    }

    foreach ($entry in $updates.GetEnumerator()) {
        Set-ConfiguredSecret -Name $entry.Key -Value $entry.Value
    }

    Write-Host "Maven Central publisher secrets updated:"
    foreach ($secretName in $updates.Keys) {
        Write-Host "  $secretName"
    }
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
        Write-Host "Uploading signing public key to $keyServerUploadUrl..."

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

    Write-Host "Key server upload URLs: $($KeyServers -join ', ')"

    $results = Invoke-PublicKeyServerUpload -SigningPublicKey $SigningPublicKey -KeyServers $KeyServers
    Write-Host ""
    Write-Host "Signing public key upload results:"
    $results | Format-Table -AutoSize | Out-Host
    Test-PublicKeyUploadResults -Results $results
    return $results
}

function Invoke-MavenCentralPublish {
    Repair-MavenCentralSecrets | Out-Null
    $secrets = Get-SecretsJson

    $javaExecutable = Resolve-JavaExecutable -JavaExecutable (Get-RequiredResolvedConfiguredValue -Secrets $secrets -Name "SONATYPE_MAVEN_CENTRAL_JAVA_EXECUTABLE")
    $javaHome = Get-JavaHomeFromExecutable -JavaExecutablePath $javaExecutable
    $resolvedProjectGradleCommand = Resolve-ProjectGradleCommand -ProjectGradleCommand $ProjectGradleCommand
    $resolvedProjectDirectory = Split-Path -Path $resolvedProjectGradleCommand -Parent
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

    $null = Publish-MavenCentralPublicKey -SigningPublicKey $signingPublicKey -KeyServers $keyServers

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

    Write-Host "Publishing package environment loaded."
    Write-Host "SONATYPE_MAVEN_CENTRAL_USERNAME: $sonatypeUsername"
    Write-Host "SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE: $publishingType"
    Write-Host "JAVA_HOME: $javaHome"
    Write-Host "Project directory: $resolvedProjectDirectory"
    Write-Host "Project Gradle command: $resolvedProjectGradleCommand"
    Write-Host ""
    Write-Host "Running publishReleaseToCentralPortal..."

    Push-Location -LiteralPath $resolvedProjectDirectory
    try {
        & $resolvedProjectGradleCommand "publishReleaseToCentralPortal" "--stacktrace"
        if ($LASTEXITCODE -ne 0) {
            throw "Gradle publish failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    Write-Host "Maven Central publish completed."
}

function Invoke-SigningPublicKeyUpload {
    Repair-MavenCentralSecrets | Out-Null
    $secrets = Get-SecretsJson

    if ($ProvidedParameterNames -contains "File") {
        $resolvedFilePath = Resolve-FullPath -Path $File
        if (-not (Test-Path -LiteralPath $resolvedFilePath -PathType Leaf)) {
            throw "Signing public key file was not found: $resolvedFilePath"
        }

        $signingPublicKey = Get-Content -LiteralPath $resolvedFilePath -Raw
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

    $null = Publish-MavenCentralPublicKey -SigningPublicKey $signingPublicKey -KeyServers $keyServers
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
    $secretsFilePath = Invoke-SecretsManager -Parameters @{ Init = $true } | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($secretsFilePath)) {
        throw "SecretsManager.ps1 did not return the secrets file path."
    }

    return [PSCustomObject]@{
        SecretsFilePath = $secretsFilePath
        GpgKeyServersState = Repair-GpgKeyServers -SecretsFilePath $secretsFilePath
    }
}

function Initialize-MavenCentralSecrets {
    $repairResult = Repair-MavenCentralSecrets
    $secretStates = [ordered]@{}
    $secretStates[$GpgKeyServersSecretName] = $repairResult.GpgKeyServersState

    foreach ($secretName in $RequiredSecretNames) {
        if ($secretName -eq $GpgKeyServersSecretName) {
            continue
        }

        $created = Invoke-SecretsManager -Parameters @{ Add = $secretName }
        $secretStates[$secretName] = if ($created) { "Created" } else { "Existing" }
    }

    Write-Host "Maven Central publisher secrets initialized:"
    foreach ($secretName in $RequiredSecretNames) {
        Write-Host "  $secretName [$($secretStates[$secretName])]"
    }
}

if ($Init) {
    Initialize-MavenCentralSecrets
    return
}

if ($List) {
    Show-MavenCentralSecrets
    return
}

if ($Edit) {
    Edit-MavenCentralSecrets
    return
}

if ($Set) {
    Set-MavenCentralSecrets
    return
}

if ($Publish) {
    Invoke-MavenCentralPublish
    return
}

if ($UploadSigningPublicKey) {
    Invoke-SigningPublicKeyUpload
    return
}

if ($Version) {
    Show-Version
    return
}

Show-Usage
