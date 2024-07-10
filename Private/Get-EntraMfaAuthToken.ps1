function Get-EntraMfaAuthToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TenantId,
        [Parameter(Mandatory = $true)]
        [PSObject] $Credential
    )

    try {
        $tokenEndpoint = $Providers.EntraId.TokenEndpoint.Replace('_tenantId_',$TenantId)

        if ($Credential -is [System.Security.Cryptography.X509Certificates.X509Certificate] -or $Credential -is [string]) {
            if ($Credential -is [string]) {
                $cert = Select-Certificate -CertificateThumbprint $Credential
                if ($cert -isnot [System.Security.Cryptography.X509Certificates.X509Certificate]) {
                    throw "Can't proceed with X509Certificates authentication"
                }
            }
            else {
                $cert = $Credential
            }
            #
            $currentDateTime = [int](Get-Date).ToUniversalTime().Subtract((Get-Date -Date "1970-01-01")).TotalSeconds
            $nbf = $currentDateTime
            $iat = $nbf
            $exp = $currentDateTime + 60
            $jwtHeader = @{
                alg = "RS256"
                typ = "JWT"
                x5t = [Convert]::ToBase64String($cert.GetCertHash())
            }
            $jwtPayload = @{
                aud = $tokenEndpoint
                iss = $Providers.EntraId.MfaAppId
                sub = $Providers.EntraId.MfaAppId
                jti = (New-Guid).Guid
                nbf = $nbf
                iat = $iat
                exp = $exp
            }
            $jwtHeaderBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $jwtHeader -Compress)))
            $jwtPayloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $jwtPayload -Compress)))
            $jwtToSign = "$jwtHeaderBase64.$jwtPayloadBase64"
            $certificatePrivateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
            $signatureBytes = $certificatePrivateKey.SignData([Text.Encoding]::UTF8.GetBytes($jwtToSign), [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
            $jwtSignatureBase64 = [Convert]::ToBase64String($signatureBytes)
            $clientAssertion = "$jwtToSign.$jwtSignatureBase64"
            #
            $body = @{
                client_id = $Providers.EntraId.MfaAppId
                client_assertion = $clientAssertion
                client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
                scope = "https://adnotifications.windowsazure.com/StrongAuthenticationService.svc/Connector/.default"
                grant_type = "client_credentials"
            }
        }
        elseif ($Credential -is [System.Security.SecureString]) {
            $clientSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential))
            $body = @{
                client_id     = $Providers.EntraId.MfaAppId
                client_secret = $clientSecret
                scope         = "https://adnotifications.windowsazure.com/StrongAuthenticationService.svc/Connector/.default"
                grant_type    = "client_credentials"
            }
        }
        else {
            throw "Invalid -Credential type"
        }

        $response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body -ContentType "application/x-www-form-urlencoded" -ErrorAction SilentlyContinue
        if (-not $response.access_token) {
            throw "Got '$response'"
        }
        $response
    }
    catch {
        throw "Failed to get access token - $_"
    }
}

