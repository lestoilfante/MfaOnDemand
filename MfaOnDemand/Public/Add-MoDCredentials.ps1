function Add-MoDCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("EntraId")]
        [string] $Provider,
        [Parameter(Mandatory = $true)]
        [string] $TenantId,
        [Parameter(Mandatory = $true, ParameterSetName='Type')]
        [ValidateSet("Password","Certificate")]
        [string] $Type,
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [PSObject]$MyCertificate
    )

    process {
        try {
            if ($Type -eq "Certificate") {
                if ($null -eq $MyCertificate) {
                    Write-Warning "With -Type 'Certificate' -MyCertificate [?|New|X509Certificate|X509Certificate.Thumbprint] is required"
                    return
                }
                if ($MyCertificate -is [System.Security.Cryptography.X509Certificates.X509Certificate] -or $MyCertificate -is [string]) {
                    if ($MyCertificate -is [string]) {
                        if ($MyCertificate -eq "New") {
                            $ou = $MyInvocation.MyCommand.Module.Name
                            $certArgs = @{
                                Subject = "CN=$TenantId, OU=$ou"
                                CertStoreLocation = 'Cert:\\CurrentUser\\My'
                                KeyAlgorithm = 'RSA'
                                KeyLength = 2048
                                HashAlgorithm = "SHA256"
                                NotAfter = (Get-Date).AddYears(2).ToUniversalTime()
                                TextExtension = @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
                                KeyUsage = "None"
                                FriendlyName = $ou
                            }
                            $cert = New-SelfSignedCertificate @certArgs
                        }
                        else {
                            $cert = Select-Certificate -CertificateThumbprint $MyCertificate
                            if ($cert -isnot [System.Security.Cryptography.X509Certificates.X509Certificate]) {
                                throw "Failed to get X509Certificate"
                            }
                        }
                    }
                    else {
                        $cert = $MyCertificate
                    }
                }
            }
            switch ($Provider) {
                "EntraId" {
                    $secret = Add-EntraMfaCredentials -TenantId $TenantId -Type $Type -Certificate $cert
                    Start-Sleep -Seconds 5  #Wait few secs to sync on cloud side before returning to caller, allows a working pipelining like => Add-Credential | Invoke-Mfa
                    if ($Type -eq "Password") {
                        return $secret
                    }
                    else {
                        return $cert.Thumbprint
                    }
                }
            }
        }
        catch {
            Write-Error $_.Exception.Message
            return
        }
    }
}
