function Add-EntraMfaCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TenantId,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Password","Certificate")]
        [string] $Type,
        [Parameter(Mandatory = $false)]
        [System.Security.Cryptography.X509Certificates.X509Certificate]$Certificate
    )
    $moduleName = "Microsoft.Graph"
    $g = Get-Module -ListAvailable -Name $moduleName
    if ($null -eq $g) {
        throw "Module '$moduleName' is not available."
    }
    try {
        $appId = $Providers.EntraId.MfaAppId
        Connect-MgGraph -NoWelcome -TenantId $TenantId -Scopes 'Application.ReadWrite.All'
        $mfaSvcPrincipal = Get-MgServicePrincipal -Filter "appid eq '$appId'"
        if ($Type -eq "Password") {
            $passwordCredential = @{
                DisplayName = $MyInvocation.MyCommand.ModuleName
                EndDateTime = (Get-Date).ToUniversalTime().AddDays($Providers.EntraId.PasswordExpiration).ToString("yyyy-MM-ddTHH:mm:ss")
            }
            $secret = Add-MgServicePrincipalPassword -ServicePrincipalId $mfaSvcPrincipal.Id -PasswordCredential $passwordCredential
            Disconnect-MgGraph
            return $secret.SecretText
        }
        elseif ($Type -eq "Certificate" -and $Certificate) {
            $keyCredentials = $mfaSvcPrincipal.KeyCredentials
            $newKey = @(@{
                CustomKeyIdentifier = $null
                Usage = "Verify"
                Type = "AsymmetricX509Cert"
                Key = $Certificate.RawData
                KeyId = (New-Guid).Guid
                DisplayName = $Certificate.Subject
                EndDateTime = (Get-Date).ToUniversalTime().AddDays($Providers.EntraId.CertificateExpiration).ToString("yyyy-MM-ddTHH:mm:ss")
                AdditionalProperties = $null
            })
            $keyCredentials += $newKey
            Update-MgServicePrincipal -ServicePrincipalId $mfaSvcPrincipal.Id -KeyCredentials $keyCredentials -ErrorAction Stop
            Disconnect-MgGraph
            return $null
        }
        else {
            throw "Unexpected error"
        }
    }
    catch {
        throw "Error adding ServicePrincipal credentials - $_"
    }
}

