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
$ScriptVersion = "0.3.2"
$ProvidedParameterNames = @($PSBoundParameters.Keys)

$GpgKeyServersSecretName = "SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS"
$DefaultGpgKeyServers = @(
    "keyserver.ubuntu.com",
    "pgp.mit.edu",
    "keys.openpgp.org"
)

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
        "keyserver.ubuntu.com",
        "pgp.mit.edu",
        "keys.openpgp.org"
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
    The GPG key servers value is validated and repaired before opening.

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
    GPG key servers are intentionally not handled by -Set yet.

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
      SONATYPE_MAVEN_CENTRAL_SIGNING_PUBLIC_KEY
      SONATYPE_MAVEN_CENTRAL_PASSWORD
      SONATYPE_MAVEN_CENTRAL_USERNAME
    SONATYPE_MAVEN_CENTRAL_PUBLISHING_TYPE defaults to user_managed when empty.
    SONATYPE_MAVEN_CENTRAL_GPG_KEY_SERVERS is validated and repaired before publishing.

    Examples:
      .\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand "..\MyJvmProject\gradlew.bat"
      .\MavenCentralPublisher.ps1 -Publish -ProjectGradleCommand "../MyJvmProject/gradlew"

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
        throw "Required value '$Name' is missing, null, or empty. Configure it in an environment variable or secret before running -Publish."
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

function Get-GpgExecutablePath {
    $gpgCommand = Get-Command gpg -ErrorAction SilentlyContinue
    if ($null -ne $gpgCommand -and -not [string]::IsNullOrWhiteSpace($gpgCommand.Source)) {
        if (Test-Path -LiteralPath $gpgCommand.Source -PathType Leaf) {
            return $gpgCommand.Source
        }
    }

    $fallbackPaths = @(
        "C:\Program Files\GnuPG\bin\gpg.exe",
        "C:\Program Files\Git\usr\bin\gpg.exe"
    )

    foreach ($fallbackPath in $fallbackPaths) {
        if (Test-Path -LiteralPath $fallbackPath -PathType Leaf) {
            return $fallbackPath
        }
    }

    throw "GPG was not found in PATH and no supported fallback location was found. Install GnuPG or make sure 'gpg' is available."
}

function Get-PublicKeyFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GpgExecutablePath,

        [Parameter(Mandatory = $true)]
        [string]$PublicKeyPath
    )

    $output = & $GpgExecutablePath --show-keys --with-colons --fingerprint $PublicKeyPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read the public key fingerprint. GPG output: $($output -join [Environment]::NewLine)"
    }

    $fingerprint = $output |
        Where-Object { $_ -like "fpr:*" } |
        ForEach-Object { ($_ -split ":")[9] } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($fingerprint)) {
        throw "Could not extract a fingerprint from the public signing key."
    }

    return $fingerprint.Trim()
}

function Publish-PublicKeyToServers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GpgExecutablePath,

        [Parameter(Mandatory = $true)]
        [string]$PublicKeyPath,

        [Parameter(Mandatory = $true)]
        [string]$Fingerprint,

        [Parameter(Mandatory = $true)]
        [string[]]$KeyServers
    )

    $temporaryHome = Join-Path ([System.IO.Path]::GetTempPath()) ("maven-central-gpg-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $temporaryHome | Out-Null

    try {
        $importOutput = & $GpgExecutablePath --homedir $temporaryHome --import $PublicKeyPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to import the public key into the temporary GPG home. GPG output: $($importOutput -join [Environment]::NewLine)"
        }

        foreach ($keyServer in $KeyServers) {
            Write-Host "Uploading public key fingerprint $Fingerprint to $keyServer..."
            $uploadOutput = & $GpgExecutablePath --homedir $temporaryHome --keyserver $keyServer --send-keys $Fingerprint 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to upload the public key to '$keyServer'. GPG output: $($uploadOutput -join [Environment]::NewLine)"
            }
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryHome -PathType Container) {
            Remove-Item -LiteralPath $temporaryHome -Recurse -Force
        }
    }
}

function Test-PublicKeyAvailabilityOnServers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GpgExecutablePath,

        [Parameter(Mandatory = $true)]
        [string]$Fingerprint,

        [Parameter(Mandatory = $true)]
        [string[]]$KeyServers
    )

    foreach ($keyServer in $KeyServers) {
        $temporaryHome = Join-Path ([System.IO.Path]::GetTempPath()) ("maven-central-gpg-verify-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $temporaryHome | Out-Null

        try {
            Write-Host "Verifying public key fingerprint $Fingerprint on $keyServer..."
            $verifyOutput = & $GpgExecutablePath --homedir $temporaryHome --keyserver $keyServer --recv-keys $Fingerprint 2>&1
            $verifyOutputText = $verifyOutput -join [Environment]::NewLine

            $fingerprintLookup = & $GpgExecutablePath --homedir $temporaryHome --list-keys --with-colons $Fingerprint 2>&1
            $resolvedFingerprint = $fingerprintLookup |
                Where-Object { $_ -like "fpr:*" } |
                ForEach-Object { ($_ -split ":")[9] } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -First 1

            if ([string]::IsNullOrWhiteSpace($resolvedFingerprint) -or
                $resolvedFingerprint.Trim().ToUpperInvariant() -ne $Fingerprint.Trim().ToUpperInvariant()) {
                throw "Key server '$keyServer' did not return the expected public key. GPG output: $verifyOutputText"
            }
        }
        finally {
            if (Test-Path -LiteralPath $temporaryHome -PathType Container) {
                Remove-Item -LiteralPath $temporaryHome -Recurse -Force
            }
        }
    }
}

function Publish-MavenCentralPublicKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SigningPublicKey,

        [Parameter(Mandatory = $true)]
        [string[]]$KeyServers
    )

    $temporaryKeyPath = Join-Path ([System.IO.Path]::GetTempPath()) ("maven-central-public-key-" + [guid]::NewGuid().ToString("N") + ".asc")

    try {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($temporaryKeyPath, $SigningPublicKey, $utf8NoBom)
        $gpgExecutablePath = Get-GpgExecutablePath
        $fingerprint = Get-PublicKeyFingerprint -GpgExecutablePath $gpgExecutablePath -PublicKeyPath $temporaryKeyPath

        Write-Host "GPG executable: $gpgExecutablePath"
        Write-Host "Public key fingerprint: $fingerprint"
        Write-Host "Key servers: $($KeyServers -join ', ')"

        Publish-PublicKeyToServers -GpgExecutablePath $gpgExecutablePath -PublicKeyPath $temporaryKeyPath -Fingerprint $fingerprint -KeyServers $KeyServers
        Test-PublicKeyAvailabilityOnServers -GpgExecutablePath $gpgExecutablePath -Fingerprint $fingerprint -KeyServers $KeyServers
    }
    finally {
        if (Test-Path -LiteralPath $temporaryKeyPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryKeyPath -Force
        }
    }
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

    Publish-MavenCentralPublicKey -SigningPublicKey $signingPublicKey -KeyServers $keyServers

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

            if ($seen.Add($server)) {
                $normalized.Add($server)
            }
        }
    }

    foreach ($defaultServer in $DefaultGpgKeyServers) {
        if ($seen.Add($defaultServer)) {
            $normalized.Add($defaultServer)
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

if ($Version) {
    Show-Version
    return
}

Show-Usage
